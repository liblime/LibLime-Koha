#!/usr/bin/perl

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

# the next koha public release version number;
# the kohaversion is divided in 4 parts :
# - #1 : the major number. 3 atm
# - #2 : the functionnal release. 00 atm
# - #3 : the subnumber, moves only on a public release
# - #4 : the developer version. The 4th number is the database subversion. 
#        used by developers when the database changes. updatedatabase take care of the changes itself
#        and is automatically called by Auth.pm when needed.

use strict;

sub kohaversion {
    our $VERSION = '4.02.00.006';
    # version needs to be set this way
    # so that it can be picked up by Makefile.PL
    # during install
    return $VERSION;
}

1;
