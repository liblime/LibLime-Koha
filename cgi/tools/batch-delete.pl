#!/usr/bin/env perl

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

use warnings;
use strict;
use C4::Accounts;
use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Items;
use C4::Output;
use CGI;

sub main {
    my $query = CGI->new;
    my $script_name = '/cgi-bin/koha/tools/batch-delete.pl';
    my ($template, $loggedinuser, $cookie) = get_template_and_user(
        {
            script_name     => $script_name,
            template_name   => 'tools/batch-delete.tmpl',
            query           => $query,
            type            => 'intranet',
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => 'batch_item_edit', },
        }
    );

    my $delete_type = 0;
    my $delete_type_param = $query->param('delete_type');

    if ( $query->param('download_results') ) {
        print "Content-type: text/csv\n";
        print "Content-Disposition: attachment; filename='batch_delete.csv'\n\n";
        print $query->param('download_data');
        exit;
    }

    if ( $query->param('process') && ($delete_type_param eq 'delete_titles' || $delete_type_param eq 'delete_items') ) {

        my $total_deleted = 0;
        my %actions = ( delete_titles => \&delete_title, delete_items => \&delete_item );
        $delete_type = ($delete_type_param eq 'delete_titles') ? BIB() : ITEM();

        my $ids = get_ids($query);
        my @ID_loop = ();
        while (@$ids) {
            my %row_data;
            $row_data{ID}     = shift @$ids;
            $row_data{CN}     = get_cn( $row_data{ID}, $delete_type );
            $row_data{TITLE}  = get_title( $row_data{ID}, $delete_type );
            $row_data{AUTHOR} = get_author( $row_data{ID}, $delete_type );
            $row_data{STATUS} = $actions{$delete_type_param}->( $query, $row_data{ID} );
            ++$total_deleted if $row_data{STATUS} eq 'OK';
            push @ID_loop, \%row_data;
        }

        $template->param(ID_LOOP => \@ID_loop);
        $template->param(TOTAL_DELETED => $total_deleted);
    }

    $template->param(DISPLAY => $delete_type);
    output_html_with_http_headers($query, $cookie, $template->output);
}

sub BIB {
    return 2;
}

sub ITEM {
    return 3;
}

sub get_ids {
    my $query = shift;
    my $MAX_CHARS = 100; # Limit file upload characters/line.
    my $MAX_LINES = 500; # Limit file upload lines processed.

    my (@scan_ids, @barcode_ids);
    if ( $query->param('scan_identifiers') ) {
        @barcode_ids = split( ' ', $query->param('scan_identifiers') );
        my $dbh = C4::Context->dbh;
        my $db_query = 'SELECT itemnumber FROM items WHERE barcode = ?';
        for my $id (@barcode_ids) {
            my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
            push @scan_ids, $return->[0] if $return->[0];
        }
    }

    my @text_ids;
    if ( $query->param('text_identifiers') ) {
        @text_ids = split( ' ', $query->param('text_identifiers') );
    }

    my @file_ids;
    my $line_count = 0;
    if ( $query->param('file_identifiers') ) {
        my $fh = $query->param('file_identifiers');
        while (<$fh>) {
            next if length > $MAX_CHARS; # Toss out lengthy lines.
            my $line = $_;
            $line =~ s/\D/ /g;
            my @fh_ids = split /\s+/, $line;
            push @file_ids, @fh_ids;
            ++$line_count;
            last if $line_count > $MAX_LINES; # Only take so much abuse.
        }
    }

    my @ids;
    push @ids, @scan_ids, @text_ids, @file_ids;
    return \@ids;
}

sub get_cn {
    my ($id, $delete_type) = @_;
    return '' if $delete_type == BIB(); # No CN for bibs.
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT itemcallnumber FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub get_title {
    my ($id, $delete_type) = @_;
    my $dbh = C4::Context->dbh;

    if ( $delete_type == ITEM() ) { # Must use biblionumber, not itemnumber.
        my $biblio_query = 'SELECT biblionumber FROM items WHERE itemnumber = ?';
        my $biblio_result = $dbh->selectrow_arrayref( $biblio_query, undef, $id );
        $id = $biblio_result->[0];
    }

    my $db_query = 'SELECT title FROM biblio WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub get_author {
    my ($id, $delete_type) = @_;
    my $dbh = C4::Context->dbh;

    if ( $delete_type == ITEM() ) { # Must use biblionumber, not itemnumber.
        my $biblio_query = 'SELECT biblionumber FROM items WHERE itemnumber = ?';
        my $biblio_result = $dbh->selectrow_arrayref( $biblio_query, undef, $id );
        $id = $biblio_result->[0];
    }

    my $db_query = 'SELECT author FROM biblio WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub delete_title {
    my ($query, $id) = @_;
    my %fails = ();
    my %actions = (
        bib_must_exist    => \&bib_must_exist,
        items_attached    => \&items_attached,
        bib_is_on_hold    => \&bib_is_on_hold,
        aqorders_link     => \&aqorders_link,
        suggestions_link  => \&suggestions_link,
        subscription_link => \&subscription_link,
        patron_tags       => \&patron_tags,
        patron_reviews    => \&patron_reviews,
    );
    my %constraints = (
        bib_must_exist    => 1,
        items_attached    => ($query->param('items_attached')    // 1),
        bib_is_on_hold    => ($query->param('bib_is_on_hold')    // 1),
        aqorders_link     => ($query->param('aqorders_link')     // 1),
        suggestions_link  => ($query->param('suggestions_link')  // 1),
        subscription_link => ($query->param('subscription_link') // 1),
        patron_tags       => ($query->param('patron_tags')       // 1),
        patron_reviews    => ($query->param('patron_reviews')    // 1),
    );
    for my $key (keys %constraints) {
        $fails{$key} = $actions{$key}->($id) if $constraints{$key};
    }
    for my $key (keys %fails) {
        delete $fails{$key} if !$fails{$key};
    }
    if (%fails) {
        my $error = 'FAIL';
        for my $key (keys %fails) {
            $error .= " $key";
        }
        return $error;
    }
    else {
        return _delete_title($id);
    }
}

sub _delete_title {
    my $id = shift;

    # Delete all items first, otherwise DelBiblio will fail.
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT itemnumber FROM items WHERE biblionumber = ?';
    my $items = $dbh->selectall_arrayref( $db_query, undef, $id );
    map { _delete_item( $_->[0], undef) } @$items;

    # Delete the biblio.
    my $return = C4::Biblio::DelBiblio($id);

    $return ? return $return : return 'OK';
}

sub delete_item {
    my ($query, $id) = @_;
    my %fails = ();
    my %actions = (
        item_must_exist => \&item_must_exist,
        item_is_on_hold => \&item_is_on_hold,
        checked_out     => \&checked_out,
        lost            => \&lost,
        damaged         => \&damaged,
        withdrawn       => \&withdrawn,
        patron_lost     => \&patron_lost,
        periodical_link => \&periodical_link,
        course_reserve  => \&course_reserve,
    );
    my %constraints = (
        item_must_exist => 1,
        item_is_on_hold => ($query->param('item_is_on_hold') // 1),
        checked_out     => ($query->param('checked_out')     // 1),
        lost            => ($query->param('lost')            // 1),
        damaged         => ($query->param('damaged')         // 1),
        withdrawn       => ($query->param('withdrawn')       // 1),
        patron_lost     => ($query->param('patron_lost')     // 1),
        periodical_link => ($query->param('periodical_link') // 1),
        course_reserve  => ($query->param('course_reserve')  // 1),
    );
    for my $key (keys %constraints) {
        $fails{$key} = $actions{$key}->($id) if $constraints{$key};
    }
    for my $key (keys %fails) {
        delete $fails{$key} if !$fails{$key};
    }
    if (%fails) {
        my $error = 'FAIL';
        for my $key (keys %fails) {
            $error .= " $key";
        }
        return $error;
    }
    else {
        my $delete_title_param = $query->param('delete_title');
        return _delete_item( $id, $delete_title_param );
    }
}

sub _delete_item {
    my ($id, $delete_title) = @_;

    # Delete the item.
    my $dbh = C4::Context->dbh;
    my $item = C4::Biblio::GetBiblioFromItemNumber($id);
    C4::Items::DelItem( $dbh, $item->{biblionumber}, $id );

    # Delete the title if requested and if it has no items.
    if ( $delete_title && !items_attached($item->{biblionumber}) ) {
        _delete_title( $item->{biblionumber} );
    }

    # If checked out, charge the patron.
    C4::Accounts::chargelostitem($id) if checked_out($id);

    return 'OK';
}

# BIB CONSTRAINTS

sub bib_must_exist {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM biblio WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return !$return->[0];
}

sub items_attached {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM items WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub bib_is_on_hold {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM reserves WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub aqorders_link {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM aqorders WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub suggestions_link {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM suggestions WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub subscription_link {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM subscription WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub patron_tags {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM tags_all WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub patron_reviews {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM reviews WHERE biblionumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

# ITEM CONSTRAINTS

sub item_must_exist {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return !$return->[0];
}

sub item_is_on_hold {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query =
        q{SELECT reservenumber
          FROM reserves
          WHERE itemnumber=?
          AND (found <> 'S' OR found IS NULL)
          ORDER BY priority ASC LIMIT 1};
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub checked_out {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT onloan FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub lost {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT itemlost FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub damaged {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT damaged FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub withdrawn {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT wthdrawn FROM items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub patron_lost {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM lost_items WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub periodical_link {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM serialitems WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

sub course_reserve {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    my $db_query = 'SELECT COUNT(*) FROM course_reserves WHERE itemnumber = ?';
    my $return = $dbh->selectrow_arrayref( $db_query, undef, $id );
    return $return->[0];
}

main();
