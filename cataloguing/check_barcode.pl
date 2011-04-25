#!/usr/bin/perl

## This script is meant to be called via ajax, and
## is passed one param, 'barcode'. If the barcode
## exists, the script will reply with a json
## structure containing the title and itemnumber

# Copyright 2010 Kyle Hall <kyle@kylehall.info>
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

use strict;
use warnings;

use CGI;
use JSON;

use C4::Auth;
use C4::Biblio;
use C4::Items;
use C4::Circulation;
use C4::Reserves;

my $cgi = new CGI;

my $barcode = $cgi->param('barcode');

my $params;

my $item = GetItem( '', $barcode );
  
if ( $item->{'itemnumber'} ) {
  my $biblio = GetBiblioData( $item->{'biblionumber'} );
  my $issue = GetItemIssue( $item->{'itemnumber'} );
  my ( $item_level_reserves ) = GetReservesFromItemnumber( $item->{'itemnumber'} );
  my ( $bib_level_reserves ) = GetReservesFromBiblionumber( $item->{'biblionumber'}, '', 1 );
    
  $params->{'itemnumber'} = $item->{'itemnumber'};
  $params->{'location'} = $item->{'location'};
  $params->{'holdingbranch'} = $item->{'holdingbranch'};
  $params->{'homebranch'} = $item->{'homebranch'};
  $params->{'title'} = $biblio->{'title'};
  $params->{'item_level_reserves'} = $item_level_reserves;
  $params->{'bib_level_reserves'} = $bib_level_reserves;
  
  if ( $issue ) {
    $params->{'date_due'} = C4::Dates->new( $issue->{'date_due'}, "iso")->output;
  }
}

my $json = to_json( $params );

warn Data::Dumper::Dumper( $json );

print $cgi->header('application/json');
print $json;

