#!/usr/bin/env perl

# Copyright 2011 Kyle M Hall <kyle@kylehall.info>
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use Koha;
use CGI;

use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Dates;
use C4::ReceiptTemplates;

my $cgi = new CGI;

my ( $template, $loggedin_borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/receipt_generation.tmpl',
        query           => $cgi,
        type            => 'intranet',
        authnotrequired => 0,
    }
);

$template->param( delay_load => 0 );

my $action         = $cgi->param('action');
my $borrowernumber = $cgi->param('borrowernumber');
my $itemnumber     = $cgi->param('itemnumber');

my $branchcode = C4::Context->userenv->{'branch'};

my $receipt_template =
  GetReceiptTemplate( { action => $action, branchcode => $branchcode } );
my $content = $receipt_template->{'content'};

## Process Check Out Receipts
if ( $action eq 'check_out' || $action eq 'check_out_quick' ) {
    my $today_issues_data = _get_issues_data( $borrowernumber, 'today' );

    $content =
      _replace_loop( $content, $today_issues_data, 'TodaysIssuesList' );

    my $previous_issues_data = _get_issues_data( $borrowernumber, 'previous' );
    $content =
      _replace_loop( $content, $previous_issues_data, 'PreviousIssuesList' );
}
## Process Check In Receipts
elsif ( $action eq 'check_in' ) {
    my @barcodes     = $cgi->param('barcode');
    my $returns_data = _get_returns_data(@barcodes);
    $content = _replace_loop( $content, $returns_data, 'PreviousIssuesList' );
}
## Process Check In - Barcode Not Found
elsif ( $action eq 'not_found' ) {
    my $barcode = $cgi->param('barcode');
    my $data;
    $data->{'items.barcode'} = $barcode;
    $content = _replace( $content, $data );
}
## Process Check In - Lost Item Found
elsif ( $action eq 'claims_returned_found' ) {
    my $barcode = $cgi->param('barcode');
    my $data    = _get_returns_data($barcode);
    $data = $data->[0];
    $content = _replace( $content, $data );
}
## Process Fine Payments
elsif ( $action eq 'payment_received' ) {
    my $borrowernumber = $cgi->param('borrowernumber');
    my $data;

    $data = _get_fines_data( $borrowernumber, 'todayspayments' );
    $content = _replace_loop( $content, $data, 'TodaysPaymentsList' );

    $data = _get_fines_data( $borrowernumber, 'recentfines' );
    $content = _replace_loop( $content, $data, 'RecentFinesList' );

    $content = _replace( $content, { TotalOwed => C4::Accounts::gettotalowed($borrowernumber)->value } );
}
## Process Hold Found Receipts
elsif ( $action eq 'hold_found' ) {
    my $borrowernumber = $cgi->param('borrowernumber');
    my $biblionumber   = $cgi->param('biblionumber');
    my $reservenumber  = $cgi->param('reservenumber');

    $template->param( delay_load => 1 );

    my $data = _get_hold_data($reservenumber);
    $content = _replace( $content, $data );
}
## Process Transit Hold Found Receipts
elsif ( $action eq 'transit_hold' ) {
    my $borrowernumber = $cgi->param('borrowernumber');
    my $biblionumber   = $cgi->param('biblionumber');
    my $reservenumber  = $cgi->param('reservenumber');

    $template->param( delay_load => 1 );

    my $data = _get_hold_data($reservenumber);
    $content = _replace( $content, $data );
}

## Fill in branch data
my $branch_data = _get_branch_data($branchcode);
$content = _replace( $content, $branch_data );

## Fill in non-looped data about borrower
if ($borrowernumber) {
    my $borrower_data = _get_borrower_data($borrowernumber);
    $content = _replace( $content, $borrower_data );
}

## Fill in non-database variables
my $data;
$data->{'CURRENT_DATE'} = C4::Dates->new()->output();
$content = _replace( $content, $data );

$template->param( output => $content );

output_html_with_http_headers $cgi, $cookie, $template->output;

sub _replace {
    my ( $content, $data ) = @_;

    my $date = C4::Dates->new();

    while ( my ( $key, $value ) = each %$data ) {
        if ( _is_date($value) )
        { ## If the key looks like a date ( starts with YYY-MM-DD ), convert it to MM/DD/YYYY
            $value = C4::Dates::format_date($value);
        }

        $content =~ s/<<$key>>/$value/g;
    }

    return $content;
}

sub _replace_loop {
    my ( $content, $data, $tag ) = @_;

    my ( $content_head, $content_loop, $content_foot ) =
      _split_out_loop( $content, $tag );

    my $new_content_loop;
    foreach my $d (@$data) {
        my $c = $content_loop // '';
        while ( my ( $key, $value ) = each %$d ) {
            $value //= '';
            if ( _is_date($value) )
            { ## If the key looks like a date ( starts with YYY-MM-DD ), convert it to MM/DD/YYYY
                $value = C4::Dates::format_date($value);
            }

            $c =~ s/<<$key>>/$value/g;
        }
        $new_content_loop .= $c;
    }

    return $content_head . $new_content_loop . $content_foot;
}

sub _split_out_loop {
    my ( $content, $tag ) = @_;

    my ( $content_head, $tmp )          = split( /<<Begin$tag>>/, $content );
    my ( $content_loop, $content_foot ) = split( /<<End$tag>>/,   $tmp );

    return ( $content_head, $content_loop, $content_foot );
}

sub _get_branch_data {
    my ($branchcode) = @_;

    my $columns = MuxColumnsForSQL( GetTableColumnsFor('branches') );

    my $dbh    = C4::Context->dbh;
    my $branch = $dbh->selectrow_hashref(
        "SELECT $columns FROM branches WHERE branchcode = ?",
        undef, $branchcode );

    return $branch;
}

sub _get_borrower_data {
    my ($borrowernumber) = @_;

    my $columns = MuxColumnsForSQL( GetTableColumnsFor('borrowers') );

    my $dbh      = C4::Context->dbh;
    my $borrower = $dbh->selectrow_hashref(
        "SELECT $columns FROM borrowers WHERE borrowernumber = ?",
        undef, $borrowernumber );

    return $borrower;
}

sub _get_issues_data {
    my ( $borrowernumber, $when ) = @_;

    my @tables = ( 'biblio', 'biblioitems', 'items', 'borrowers', 'issues' );
    my $columns = MuxColumnsForSQL( GetTableColumnsFor(@tables) );

    my $sql = "
        SELECT $columns FROM borrowers 
        LEFT JOIN issues ON issues.borrowernumber = borrowers.borrowernumber
        LEFT JOIN items ON issues.itemnumber = items.itemnumber
        LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
        LEFT JOIN biblio on items.biblionumber = biblio.biblionumber
        WHERE borrowers.borrowernumber = ?
    ";

    $sql .= " AND issuedate = CURDATE()" if ( $when eq 'today' );
    $sql .= " AND issuedate < CURDATE()" if ( $when eq 'previous' );

    return C4::Context->dbh->selectall_arrayref( $sql, { Slice => {} },
        $borrowernumber );
}

sub _get_returns_data {
    my @barcodes = @_;

    my @tables = ( 'biblio', 'biblioitems', 'items', 'borrowers', 'issues' );
    my $columns = MuxColumnsForSQL( GetTableColumnsFor(@tables) );

    my $barcode_places = join( ',', split(//, '?' x @barcodes) );

    my $sql = "
        SELECT $columns FROM items
        LEFT JOIN old_issues AS issues ON issues.itemnumber = items.itemnumber
        LEFT JOIN borrowers ON borrowers.borrowernumber = issues.borrowernumber
        LEFT JOIN biblioitems ON biblioitems.biblioitemnumber = items.biblioitemnumber
        LEFT JOIN biblio on biblio.biblionumber = items.biblionumber
        WHERE items.barcode IN ( $barcode_places )
        GROUP BY issues.itemnumber
        ORDER BY issuedate DESC;
    ";

    return C4::Context->dbh->selectall_arrayref( $sql, { Slice => {} }, @barcodes );

}

sub _get_hold_data {
    my ($reservenumber) = @_;

    my @tables = (
        'biblio', 'biblioitems', 'items', 'borrowers', 'reserves',
        'branchtransfers', { table => 'branches', name => 'recieving_branch' }
    );
    my $columns = MuxColumnsForSQL( GetTableColumnsFor(@tables) );

    my $sql = "
        SELECT $columns FROM reserves
        LEFT JOIN borrowers ON borrowers.borrowernumber = reserves.borrowernumber
        LEFT JOIN items ON items.itemnumber = reserves.itemnumber
        LEFT JOIN biblio on biblio.biblionumber = reserves.biblionumber
        LEFT JOIN biblioitems ON biblioitems.biblioitemnumber = items.biblioitemnumber
        LEFT JOIN branchtransfers ON branchtransfers.itemnumber = items.itemnumber
        LEFT JOIN branches AS recieving_branch ON recieving_branch.branchcode = branchtransfers.tobranch
        WHERE 
        reserves.reservenumber = ?
    ";

    return C4::Context->dbh->selectrow_hashref( $sql, undef, $reservenumber );
}

sub _get_fines_data {
    my ( $borrowernumber, $when ) = @_;
    my $loopdata;
    if($when eq 'todayspayments'){
        # payments are negative...
        $loopdata = C4::Accounts::getpayments($borrowernumber, since=>C4::Dates->new());
        for my $data (@$loopdata){
            $data->{amount} = -1* $data->{amount};
            $data->{"fees-payments.".$_} = (($_ =~ /amount/) ? $data->{$_}->value : $data->{$_}) for (keys %$data);  # fake the 'table name'
            # Cycle through the non-lost item transactions (which are
            # accounted for differently) to get the title of the item
            # from the fee description.
            if ($data->{description} !~ /^Lost Item/) {
                my $num_trans = scalar @{$data->{transactions}};
                if ($num_trans) {
                    for my $nt (0..$num_trans-1) {
                        my $fee_id = $data->{transactions}[$nt]->{fee_id};
                        my $fee = C4::Accounts::getfee($fee_id);
                        my $trans_amt = sprintf "%.2f", (-1 * $data->{transactions}[$nt]->{amount}->value);
                        $data->{'fees-payments.description'} .= "<br>&nbsp;&nbsp;&nbsp;&nbsp;$fee->{description}:&nbsp;&nbsp;$trans_amt";
                    }
                }
            }
        }
    } elsif($when eq 'recentfines'){
        #Include last 7 fines.
        $loopdata = C4::Accounts::getcharges($borrowernumber, limit=>7);
        for my $data (@$loopdata){
            $data->{date} = $data->{timestamp};
            $data->{"fees-payments.".$_} = (($_ =~ /amount/) ? $data->{$_}->value : $data->{$_}) for (keys %$data);
        }
        # note date and timestamp are different in payments and fees.
    }

    return $loopdata;
}

sub _is_date {
    ## Returns true if $value begins with YYYY-MM-DD
    my ($value) = @_;
    return 0 unless $value;
    return ( $value =~ /^(\d{4})(\-)(\d{1,2})\2(\d{1,2})/ );
}

