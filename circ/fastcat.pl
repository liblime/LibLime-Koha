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

use strict;
use warnings;

use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Branch;    # GetBranches
use C4::Koha;      # GetPrinter
use C4::Biblio;
use C4::Items;
use CGI::Session;
use MARC::Record;
use MARC::Field;

my $query = new CGI;

my $barcode        = $query->param('barcode');
my $borrowernumber = $query->param('borrowernumber');
my $duedatespec    = $query->param('duedatespec');
my $branch         = $query->param('branch');
my $stickyduedate  = $query->param('stickyduedate');

# TODO this should not be hard coded
my $itemnotes = 'ROUTE TO CATALOGUING - FASTADD RECORD';
my $write_record = $query->param('havedata');    # Coming from fastcat not circ
my $author       = $query->param('author');
my $title        = $query->param('title');
my $isbn         = $query->param('isbn');
my $notes        = $query->param('notes');
my $publishercode      = $query->param('publishercode');
my $publicationyear    = $query->param('publicationyear');
my $place              = $query->param('place');
my $homebranch         = $query->param('homebranch');
my $holdingbranch      = $query->param('holdingbranch');
my $itemtype           = $query->param('itemtype');
my $ccode              = $query->param('ccode');
my $itemcallnumber     = $query->param('itemcallnumber');
my $location           = $query->param('location');
my $permanent_location = $query->param('permanent_location');

#my $branch = $query->param('branch');
#if ($branch){
#    # update our session so the userenv is updated
#    my $sessionID = $query->cookie("CGISESSID") ;
#    my $session = get_session($sessionID);
#    $session->param('branch',$branch);
#    my $branchname = GetBranchName($branch);
#    $session->param('branchname',$branchname);
#}
#
#my $printer = $query->param('printer');
#if ($printer){
#    # update our session so the userenv is updated
#  my $sessionID = $query->cookie("CGISESSID") ;
#  my $session = get_session($sessionID);
#  $session->param('branchprinter',$printer);
#
#}
#if (!C4::Context->userenv && !$branch){
#  my $sessionID = $query->cookie("CGISESSID") ;
#  my $session = get_session($sessionID);
#}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'circ/fastcat.tmpl',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { circulate => q{*} },
    }
);

if ($write_record) {
    my $bib_record    = MARC::Record->new();
    my $author_tag    = q{100};
    my $title_tag     = q{245};
    my $note_tag      = q{500};
    my $isbn_tag      = q{020};
    my $publisher_tag = q{260};

    if ($author) {
        my $field = MARC::Field->new( $author_tag, '1', q{ }, a => $author );
        $bib_record->append_fields($field);
    }
    if ($title) {
        my $field = MARC::Field->new( $title_tag, '1', '0', a => $title );
        $bib_record->append_fields($field);
    }
    if ($notes) {
        my $field = MARC::Field->new( $note_tag, q{ }, q{ }, a => $notes );
        $bib_record->append_fields($field);
    }
    if ($isbn) {
        my $field = MARC::Field->new( $isbn_tag, q{ }, q{ }, a => $isbn );
        $bib_record->append_fields($field);
    }
    my @publisher_fields;
    if ($place) {
        push @publisher_fields, 'a', $place;
    }
    if ($publishercode) {
        push @publisher_fields, 'b', $publishercode;
    }
    if ($publicationyear) {
        push @publisher_fields, 'c', $publicationyear;
    }
    if (@publisher_fields) {
        my $field =
          MARC::Field->new( $publisher_tag, q{ }, q{ }, @publisher_fields );
        $bib_record->append_fields($field);
    }

    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $bib_record, q{} );

    my $item = {
        itemnotes => $itemnotes,
        barcode   => $barcode,
    };
    if ($homebranch) {
        $item->{homebranch} = $homebranch;
    }
    if ($holdingbranch) {
        $item->{holdingbranch} = $holdingbranch;
    }
    if ($itemtype) {
        $item->{itype} = $itemtype;
    }
    if ($ccode) {
        $item->{ccode} = $ccode;
    }
    if ($itemcallnumber) {
        $item->{itemcallnumber} = $itemcallnumber;
    }
    if ($location) {
        $item->{location} = $location;
    }
    if ($permanent_location) {
        $item->{permanent_location} = $permanent_location;
    }

    my $itemnumber;
    ( $biblionumber, $biblioitemnumber, $itemnumber ) =
      AddItem( $item, $biblionumber );
    my $redirect_string = '/cgi-bin/koha/circ/circulation.pl';
    if ($borrowernumber) {
        $redirect_string .= "?borrowernumber=$borrowernumber";
        $redirect_string .= '&amp;barcode=';
        $redirect_string .= $barcode;
        if ($duedatespec) {
            $redirect_string .= '&amp;duedatespec=';
            $redirect_string .= $duedatespec;
            if ($stickyduedate) {
                $redirect_string .= '&amp;stickyduedate=';
                $redirect_string .= $stickyduedate;
            }
        }
    }
    print $query->redirect($redirect_string);
}    # end of adding item

my $dbh           = C4::Context->dbh;
my $itemtypesloop = get_item_type_loop($dbh);

$template->param( itemtypesloop => $itemtypesloop );

my $ccodes_loop = get_av_loop( $dbh, 'CCODE' );
$template->param( ccodesloop => $ccodes_loop );

my $locationsloop = get_av_loop( $dbh, 'LOC' );
$template->param( locationsloop => $locationsloop );

my $branch_loop = get_branch_list( $dbh, $homebranch );
$template->param( branchloop => $branch_loop );


if ($duedatespec) {
    $template->param( duedatespec   => $duedatespec );
    $template->param( stickyduedate => $stickyduedate );
}

$template->param(
    fastcat        => 1,
    barcode        => $barcode,
    borrowernumber => $borrowernumber,
    branch         => $branch,

);

output_html_with_http_headers $query, $cookie, $template->output;

sub get_item_type_loop {
    my $dbh = shift;

    my $loop = [
        {
            value       => q{},
            selected    => 1,
            description => q{},
        },
    ];
    my $sql_query =
      'SELECT itemtype, description FROM itemtypes ORDER BY description';
    my @types = @{ $dbh->selectall_arrayref( $sql_query, { Slice => {} } ) };
    for my $it (@types) {
        push @{$loop},
          {
            value       => $it->{itemtype},
            description => $it->{description},
            selected    => undef,
          };
    }
    return $loop;
}

sub get_av_loop {
    my $dbh = shift;
    my $cat = shift;

    my $loop = [
        {
            value       => q{},
            selected    => 1,
            description => q{},
        },
    ];
    my $sql_query =
q{SELECT lib, authorised_value FROM authorised_values WHERE category = ? ORDER BY lib};
    my @tuples =
      @{ $dbh->selectall_arrayref( $sql_query, { Slice => {} }, $cat ) };
    for my $t (@tuples) {
        push @{$loop},
          {
            value       => $t->{authorised_value},
            description => $t->{lib},
            selected    => undef,
          };
    }
    return $loop;
}

sub get_branch_list {
    my $dbh     = shift;
    my $default = shift;
    my $loop    = [];
    my $sql_query =
      q{SELECT branchcode, branchname FROM branches ORDER BY branchname};
    my @tuples = @{ $dbh->selectall_arrayref( $sql_query, { Slice => {} } ) };
    for my $t (@tuples) {
        push @{$loop},
          {
            value       => $t->{branchcode},
            description => $t->{branchname},
            selected    => ($t->{branchcode} ~~ $default) ? 1 : undef
          };
    }
    return $loop;
}
