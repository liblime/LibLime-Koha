#!/usr/bin/perl

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

use C4::Output;

use C4::Members;
use C4::Members::Lists;

my $input = new CGI;

my $op = $input->param('op');
my $list_id = $input->param('list_id');
my $borrowernumber = $input->param('borrowernumber');

if ( $op eq 'add' ) {
    AddBorrowerToList({
        list_id => $list_id,
        borrowernumber => $borrowernumber
    });
}

if ( $op eq 'remove' ) {
    RemoveBorrowerFromList({
        list_id => $list_id,
        borrowernumber => $borrowernumber
    });
}

print $input->redirect("moremember.pl?borrowernumber=$borrowernumber");
