package C4::ItemDeleteList;

# Copyright 2009 PTFS Inc.
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

use strict;
use warnings;

use Carp;
use Koha;
use C4::Context;
use C4::Items;

{

    sub new {
        my ( $class, $arg_ref ) = @_;
        my $self = {};
        bless $self, $class;
        if ( $arg_ref->{list_id} ) {
            if ( $self->initialize( $arg_ref->{list_id} ) ) {
                return $self;
            }
        } else {
            if ( $self->initialize() ) {
                return $self;
            }
        }
        return;    # initialize failed
    }

    sub append {
        my ( $self, $arg_ref ) = @_;
        if ( $arg_ref->{itemnumber} and $arg_ref->{biblionumber} ) {
            $self->{insert_sth}->execute(
                $self->{ID},
                $arg_ref->{itemnumber},
                $arg_ref->{biblionumber}
            );
        } else {
            carp('append not passed itemnumber and biblionumber');
        }
        return;
    }

    sub item_barcodes {
        my $self   = shift;
        my $dbh    = C4::Context::dbh;
        my $bc_ref = $dbh->selectall_arrayref(
'SELECT i.barcode from items i, itemdeletelist idl where idl.list_id = ? and i.itemnumber = idl.itemnumber',
            { Slice => {} },
            $self->{ID}
        );
        my $bc = [];
        for my $row ( @{$bc_ref} ) {
            push @{$bc}, $row->{barcode};
        }
        return $bc;
    }

    sub get_list_array {
        my $self = shift;
        my $dbh  = C4::Context::dbh;
        my $arr  = $dbh->selectall_arrayref(
'SELECT idl.itemnumber, idl.biblionumber, i.barcode from items i, itemdeletelist idl where idl.list_id = ? and i.itemnumber = idl.itemnumber',
            { Slice => {} },
            $self->{ID}
        );
        return $arr;
    }

    sub rowcount {
        my $self  = shift;
        my $dbh   = C4::Context::dbh;
        my $count = (
            $dbh->selectrow_array(
'SELECT COUNT(*) from itemdeletelist where list_id = ? AND itemnumber > 0',
                {},
                $self->{ID}
            )
        )[0];
        return $count;
    }

    sub list_id {
        my $self = shift;
        return $self->{ID};
    }

    sub remove_all {
        my $self = shift;
        my $dbh  = C4::Context::dbh;
        $dbh->do( 'DELETE from itemdeletelist where list_id = ?',
            {}, $self->{ID} );
        return;
    }

    sub remove {
        my $self = shift;
        my $item = shift;
        my $dbh  = C4::Context::dbh;
        $dbh->do(
            'DELETE from itemdeletelist where list_id = ? AND itemnumber = ?',
            {}, $self->{ID}, $item );
        return;
    }

    sub DESTROY {
        my $self = shift;

        # remove a placeholder for an empty list
        if ( $self->{new_list} && $self->{new_list} == 1 ) {
            my $dbh = C4::Context::dbh;
            $dbh->do(
'DELETE from itemdeletelist where list_id = ? AND itemnumber = 0',
                {}, $self->{ID}
            );
        }
        return;
    }

    sub initialize {
        my $self    = shift;
        my $list_id = shift;
        my $dbh     = C4::Context::dbh;

        $self->{insert_sth} = $dbh->prepare(
'INSERT INTO itemdeletelist (list_id, itemnumber, biblionumber) VALUES (?, ?, ?)'
        );
        if ( !$list_id ) {

            # Ah for a db and sequences
            my $id = (
                $dbh->selectrow_array(
                    'SELECT MAX(list_id) from itemdeletelist')
            )[0];
            if ($id) {
                $self->{ID} = $id + 1;
            } else {
                $self->{ID} = 1;
            }
            $self->{insert_sth}->execute( $self->{ID}, 0, 0 );
            $self->{new_list} = 1;
        } else {
            my $count = (
                $dbh->selectrow_array(
                    'SELECT COUNT(*) from itemdeletelist where list_id = ?',
                    {}, $list_id
                )
            )[0];
            if ($count) {
                $self->{ID} = $list_id;
            } else {
                return;    # can't open an empty list
            }
        }

        return 1;
    }
}
1;
