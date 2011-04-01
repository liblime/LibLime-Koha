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
use C4::Biblio;
use C4::Output;
use C4::ItemDeleteList;

#use Data::Dumper;

my $query = new CGI;

my $list_id = $query->param('list_id');

my ( $template, $user, $cookie ) = get_template_and_user(
    {   template_name   => 'tools/viewitemdeletelist.tmpl',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { tools => q|batch_edit_items|, },
    }
);
if ($list_id) {
    my $command = $query->param('command');
    $command ||= 'View';
    my $idl = C4::ItemDeleteList->new( { list_id => $list_id } );
    if ( $command eq 'Confirm Delete Items' ) {
        if ($idl) {
            my $delete_list = $idl->get_list_array();
            for my $item ( @{$delete_list} ) {
                DelItem( C4::Context::dbh, $item->{biblionumber},
                    $item->{itemnumber} );
            }
            $idl->remove_all();
        }
        $template->param( action => 'items deleted' );
    } elsif ( $command eq 'Remove List' ) {
        if ($idl) {
            $idl->remove_all();
        }
        $template->param( action => 'list removed' );
    } else {
        if ($idl) {
            $template->param( list_id => $list_id );
            view_list($idl, $template);
        } else {
            get_list_of_lists($template);
        }
    }
} else {    # get a list of available lists
    get_list_of_lists($template);
}
output_html_with_http_headers $query, $cookie, $template->output;

sub get_list_of_lists {
    my $template = shift;
    my $dbh     = C4::Context::dbh;
    my $id_list = $dbh->selectall_arrayref(
        'SELECT DISTINCT list_id FROM itemdeletelist ORDER BY list_id',
        { Slice => {} } );

    $template->param( id_list => $id_list );
    return;
}

sub view_list {
    my $idl = shift;
    my $template = shift;
    my $items;
    if ($idl) {
        $items = $idl->get_list_array();
        for my $row ( @{$items} ) {
            if ( $row->{biblionumber} ) {
                $row->{biblio} = GetBiblioData( $row->{biblionumber} );
                $row->{author} = $row->{biblio}->{author};
                $row->{title}  = $row->{biblio}->{title};
            }
        }
    } else {
        $items = [];
    }
    $template->param( items => $items );
    return;
}
