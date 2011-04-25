# Copyright (c) Jesse Weaver, 2009
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
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
#-----------------------------------

use strict;
use warnings;
use POSIX qw( strftime );

our ( $VERSION, $debug, @ISA, @EXPORT );

BEGIN {
    $VERSION = 1.00;
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);
    #Get data
    push @EXPORT, qw(
        &AddBorrowerSubmit
    );
}

sub _format_date {
    return '' unless( $_[0] );
    my ( $year, $month, $day ) = split( /-/, $_[0] );

    return strftime( "%d %b %Y", 0, 0, 0, $day, $month - 1, $year - 1900 );
}

sub AddBorrowerSubmit {
    my ( $data ) = @_;

    return join( "\n", 
        "========   " . $data->{'borrowernumber'},
        "name=" . ( $data->{'surname'} || '' ) . ', ' . ( $data->{'firstname'} || '' ),
        "adr1=" . ( $data->{'address'} || '' ),
        "adr2=" . ( $data->{'address2'} || '' ),
        "adr3=",
        "adr4=",
        "city_st=" . ( $data->{'city'} || '' ),
        "zip=" . ( $data->{'zipcode'} || '' ),
        "birth=" . _format_date( $data->{'dateofbirth'} ),
        "acct=" . ( $data->{'borrowernumber'} ),
        "phone=" . ( $data->{'phone'} || '' ),
        "bphone=" . ( $data->{'phonepro'} || '' ),
        "totamt=" . sprintf( '%0.2f', $data->{'total'} ),
        "duedate=" . _format_date( $data->{'earliest_due'} ),
        "parent=" . ( $data->{'contactname'} ? ( $data->{'contactname'} . ', ' . $data->{'contactfirstname'} ) : '' ),
        "btype=" . $data->{'categorycode'},
        "ss="
    );
}

sub AddBorrowerUpdate {
    my ( $data ) = @_;

    return join( "\n",
        "========   " . $data->{'borrowernumber'},
        "name=" . ( $data->{'surname'} || '' ) . ', ' . ( $data->{'firstname'} || '' ),
        "acct=" . ( $data->{'borrowernumber'} ),
        "totamt=" . sprintf( '%0.2f', $data->{'total'} ),
        "addamt=" . sprintf( '%0.2f', $data->{'additional'} ),
        "rtnamt=" . sprintf( '%0.2f', $data->{'returned'} ),
        "waivamt=" . sprintf( '%0.2f', $data->{'waived'} ),
        "paidamt=" . sprintf( '%0.2f', $data->{'paid'} ),
    );
}

return 1;
