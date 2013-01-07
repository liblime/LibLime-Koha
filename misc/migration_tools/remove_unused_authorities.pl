#!/usr/bin/env perl

#script to administer Authorities without biblio

# Copyright 2009 BibLibre
# written 2009-05-04 by paul dot poulain at biblibre.com
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
use Koha::Authority;
use C4::Context;
use Getopt::Long;
use Koha::Solr::Service;
use Koha::Solr::Query;
use TryCatch;
use Carp;

my ($test,@authtypes);
my $want_help = 0;
GetOptions(
    'aut|authtypecode:s'    => \@authtypes,
    't'    => \$test,
    'h|help'        => \$want_help
);

if ($want_help) {
    print_usage();
    exit 0;
}

my $dbh=C4::Context->dbh;
@authtypes or @authtypes = qw( NC );
my $thresholdmin=0;
my $thresholdmax=0;
my @results;
# prepare the request to retrieve all authorities of the requested types
my $rqselect = $dbh->prepare(
    qq{SELECT authid from auth_header where authtypecode IN (}
    . join(",",map{$dbh->quote($_)}@authtypes)
    . ")"
);
$|=1;

$rqselect->execute;
my $counter=0;
my $totdeleted=0;
my $totundeleted=0;
while (my $data = $rqselect->fetchrow_hashref){
    my $authid = $data->{authid};
    try {
        my $auth = Koha::Authority->new( id => $authid );
        print '.';
        print "$counter\n" unless $counter++ % 70;
        # if found, delete, otherwise, just count
        if ( scalar @{$auth->bibs} ) {
            $totundeleted++;
        } else {
            $auth->delete unless $test;
            $totdeleted++;
        }
    }
    catch {
        carp "Problem processing authid $authid.";
    }
}

print "\n$counter authorities parsed, $totdeleted deleted and $totundeleted unchanged because used\n";

sub print_usage {
    print <<_USAGE_;
$0: Removes unused authorities.

This script will parse all authoritiestypes given as parameter, and remove authorities without any biblio attached.
warning : there is no individual confirmation !
parameters
    --aut|authtypecode TYPE       the list of authtypes to check
    --t|test                      test mode, don't delete really, just count
    --help or -h                  show this message.

_USAGE_
}
