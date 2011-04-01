#!/usr/bin/env perl

# Copyright 2009 PTFS Inc.
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
use C4::Auth;
use C4::Context;
use C4::Items;
use C4::Output;
use C4::ItemDeleteList;

my $query = new CGI;

#    # editable fields
my %ifields_map = (
    homebranch         => 'items.homebranch',
    notforloan         => 'items.notforloan',
    damaged            => 'items.damaged',
    itemlost           => 'items.itemlost',
    wthdrawn           => 'items.wthdrawn',
    holdingbranch      => 'items.holdingbranch',
    location           => 'items.location',
    permanent_location => 'items.permanent_location',
    itype              => 'items.itype',
    restricted         => 'items.restricted',
    ccode              => 'items.ccode',
);
my @ifields = keys %ifields_map;

#itemnumber biblionumber biblioitemnumber barcode dateaccessioned booksellerid homebranch price replacementprice
#replacementpricedate datelastborrowed datelastseen stack notforloan damaged itemlost wthdrawn itemcallnumber
#issues renewals reserves restricted itemnotes holdingbranch paidfor timestamp location permanent_location
#onloan cn_source cn_sort ccode materials uri itype more_subfields_xml enumchron copynumber);

my ( $template, $user, $cookie ) = get_template_and_user(
    {   template_name   => 'tools/batchitemedit.tmpl',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { tools => q|batch_edit_items|, },
    }
);

my $op = $query->param('confirm');

$op ||= q{};    # quieten warnings

my $dbh = C4::Context->dbh;

if ( $op eq 'Proceed' ) {
    my $reading_from_file = 0;
    my $uploadbarcodes    = $query->param('uploadbarcodes');
    if ( $uploadbarcodes && length $uploadbarcodes > 0 ) {
        $reading_from_file = 1;
    }

    # perform updates on item list
    my $processed_items   = [];
    my $updated           = 0;
    my $columns_to_select = get_columns_to_select($reading_from_file);
    my $columns_to_edit   = get_columns_to_edit();
    if ( $columns_to_edit && $columns_to_select ) {
        my $items = get_itemnumbers($columns_to_select);
        foreach my $item ( @{$items} ) {
            my $rep;
            $rep->{barcode} = $item->{barcode};
            ModItem( $columns_to_edit, $item->{bnum}, $item->{inum} );
            ++$updated;
            $rep->{updated} =
              1;    # None of the update routines return success/failure
            push @{$processed_items}, $rep;
        }
    } elsif ( $columns_to_edit && $reading_from_file ) {
        while ( my $barcode = <$uploadbarcodes> ) {
            chomp $barcode;
            $barcode =~ s/\r//g;
            my $rep = { barcode => $barcode, };
            my $item = GetItem( "", $barcode );
            if ($item) {
                ModItem( $columns_to_edit, $item->{biblionumber},
                    $item->{itemnumber} );
                ++$updated;
                $rep->{updated} = 1;
            } else {
                $rep->{error} = 'No matching item found';
            }
            push @{$processed_items}, $rep;
        }
    }

    $template->param(
        completed     => 1,
        edit_complete => 1,
        items_updated => $updated,
        itemsloop     => $processed_items,
    );
} elsif ( $op eq 'Delete' ) {

    # delete the items in the list
    my $reading_from_file = 0;
    my $uploadbarcodes    = $query->param('uploadbarcodes');
    if ( $uploadbarcodes && length $uploadbarcodes > 0 ) {
        $reading_from_file = 1;
    }
    my $columns_to_select = get_columns_to_select($reading_from_file);
    my $idl               = C4::ItemDeleteList->new();
    if ($reading_from_file) {
        while ( my $barcode = <$uploadbarcodes> ) {
            chomp $barcode;
            $barcode =~ s/\r//g;
            my $rep = { barcode => $barcode, };
            my $item = GetItem( q{}, $barcode );
            $idl->append(
                {   itemnumber   => $item->{itemnumber},
                    biblionumber => $item->{biblionumber},
                }
            );
        }
    } elsif ($columns_to_select) {
        my $items = get_itemnumbers($columns_to_select);
        foreach my $item ( @{$items} ) {
            $idl->append(
                {   itemnumber   => $item->{inum},
                    biblionumber => $item->{bnum},
                }
            );
        }
    }
    $template->param(
        completed       => 1,
        delete_complete => 1,
        items_updated   => $idl->rowcount(),
        itemsloop       => $idl->item_barcodes(),
        delete_list_id  => $idl->list_id(),
    );

} else {    # Generate the edit form
    my $branchloop           = get_branches();
    my $withdrawnloop        = get_withdrawn();
    my $lostloop             = get_lost_statuses();
    my $damagedloop          = get_damaged();
    my $userestrictionloop   = get_userestrict();
    my $nflloop              = get_notforloan();
    my $collectioncodeloop   = get_ccodes();
    my $shelvinglocationloop = get_shelving_locations();
    my $itemtypeloop         = get_itypes();

    # pass_selections ???
    $template->param(
        branchloop           => $branchloop,
        withdrawnloop        => $withdrawnloop,
        lostloop             => $lostloop,
        damagedloop          => $damagedloop,
        userestrictionloop   => $userestrictionloop,
        nflloop              => $nflloop,
        collectioncodeloop   => $collectioncodeloop,
        shelvinglocationloop => $shelvinglocationloop,
        itemtypeloop         => $itemtypeloop,

    );
}

#my %item;
#    # editable fields
#my @ifields = qw(
#itemnumber biblionumber biblioitemnumber barcode dateaccessioned booksellerid homebranch price replacementprice
#replacementpricedate datelastborrowed datelastseen stack notforloan damaged itemlost wthdrawn itemcallnumber
#issues renewals reserves restricted itemnotes holdingbranch paidfor timestamp location permanent_location
#onloan cn_source cn_sort ccode materials uri itype more_subfields_xml enumchron copynumber);

output_html_with_http_headers $query, $cookie, $template->output;

sub get_authorised_values {
    my $cat  = shift;
    my $loop = [];
    my $sql_query =
q{SELECT lib, authorised_value FROM authorised_values WHERE category = ? ORDER BY lib};
    my @tuples =
      @{ C4::Context->dbh->selectall_arrayref( $sql_query, { Slice => {} }, $cat ) };
    for my $t (@tuples) {
        push @{$loop},
          { value       => $t->{authorised_value},
            description => $t->{lib},
            selected    => undef,
          };
    }
    return $loop;
}

sub get_branches {
    my $loop;

    my $sql_query =
      q{SELECT branchcode, branchname FROM branches ORDER BY branchname};
    my @tuples = @{ C4::Context->dbh->selectall_arrayref( $sql_query, { Slice => {} } ) };
    for my $t (@tuples) {
        push @{$loop},
          { value       => $t->{branchcode},
            description => $t->{branchname},
            selected    => undef,
          };
    }
    return $loop;
}

sub get_withdrawn {
    return get_authorised_values('WITHDRAWN');
}

sub get_lost_statuses {
    return get_authorised_values('LOST');
}

sub get_damaged {
    return get_authorised_values('DAMAGED');
}

sub get_userestrict {
    return get_authorised_values('RESTRICTED');
}

sub get_notforloan {
    return get_authorised_values('NOT_LOAN');
}

sub get_ccodes {
    return get_authorised_values('CCODE');
}

sub get_shelving_locations {
    return get_authorised_values('LOC');
}

sub get_itypes {
    my $loop;

    my $sql_query =
      'SELECT itemtype, description FROM itemtypes ORDER BY description';
    my @types = @{ C4::Context->dbh->selectall_arrayref( $sql_query, { Slice => {} } ) };
    for my $it (@types) {
        push @{$loop},
          { value       => $it->{itemtype},
            description => $it->{description},
            selected    => 0,
          };
    }
    return $loop;
}

sub get_itemnumbers {
    my $sel = shift;
    my ( @where, @bind_parameters );

    # Get a list of matching item numbers
    # similar to C4/Items/GetItemsForInventory
    my $select =
      'SELECT items.itemnumber as inum, barcode, itemcallnumber, title, author,'
      . ' biblio.biblionumber as bnum, datelastseen FROM items '
      . 'LEFT JOIN biblio ON items.biblionumber = biblio.biblionumber '
      . 'LEFT JOIN biblioitems on items.biblionumber = biblioitems.biblionumber';

    for my $field ( keys %{$sel} ) {
        push @where,           " $ifields_map{$field} = ? ";
        push @bind_parameters, $sel->{$field};
    }

    if (@where) {
        $select .= ' where ';
        $select .= join ' and ', @where;
    } else {
        return;    # Don't do all items with no selection
    }
    my $result_set =
      $dbh->selectall_arrayref( $select, { Slice => {} }, @bind_parameters );
    return $result_set;
}

sub get_columns_to_select {
    my $upload_barcodes = shift;
    if ($upload_barcodes) {
        return;
    }
    my $select_hash = {};
    my @fields_to_update;
    for my $field (@ifields) {
        my $value = $query->param("select_$field");
        if (defined($value)) {
            push @fields_to_update, $field;
        }
    }
    for my $field (@fields_to_update) {
        my $value = $query->param($field);
        if (defined($value)) {
            $select_hash->{$field} = $value;
        }
    }

    if ( keys %{$select_hash} ) {
        return $select_hash;
    }

    # no selection criteria requested return undef
    return;
}

sub get_columns_to_edit {

    # created a hash of item fields to change
    my $edit_hash = {};
    my @fields_to_update;
    for my $field (@ifields) {
        my $value = $query->param("change_$field");
        if (defined($value)) {
            push @fields_to_update, $field;
        }
    }
    for my $field (@fields_to_update) {
        my $value = $query->param("new_$field");
        if (defined($value)) {
            $edit_hash->{$field} = $value;
        }
    }

    if ( keys %{$edit_hash} ) {
        return $edit_hash;
    }

    # no change requested return undef
    return;
}
