#!/usr/bin/env perl

# Copyright 2009 PTFS, Inc.
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

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Koha;
use C4::Context;
use C4::Dates;
#use C4::Debug;
#use C4::Letters;
#use File::Spec;
use Getopt::Long;

sub usage {
    print STDERR <<USAGE;
Usage: $0 [-h|--help] [--sessions] [-v|--verbose] [--changelog DAYS]
   -h --help         prints this help message, and exits, ignoring all other options
   --sessions        purge the sessions table.  If you use this while users are logged
                     into Koha, they will have to reconnect.
   -v --verbose      will cause the script to give you a bit more information about the run.
   --changelog DAYS purge completed entries from the changelog from more than DAYS days ago.
USAGE
    exit $_[0];
}

my ($help, $sessions, $verbose, $changelog_days);

GetOptions(
    'h|help' => \$help,
    'sessions' => \$sessions,
    'v|verbose' => \$verbose,
    'changelog:i' => \$changelog_days,
) || usage(1);

if ($help) {
    usage(0);
}

if (!($sessions || defined $changelog_days)) {
    print "You did not specify any cleanup work for the script to do.\n\n";
    usage(1);
}

my $dbh = C4::Context->dbh();
my $query;
my $sth;
my $sth2;
my $count;

if ($sessions) {
    if ($verbose){
        print "Session purge triggered.\n";
        $sth = $dbh->prepare("SELECT COUNT(*) FROM sessions");
        $sth->execute() or die $dbh->errstr;
        my @count_arr = $sth->fetchrow_array;
        print "$count_arr[0] entries will be deleted.\n";
    }
    $sth = $dbh->prepare("TRUNCATE sessions");
    $sth->execute() or die $dbh->errstr;;
    if ($verbose){
        print "Done with session purge.\n";
    }
}

if (defined $changelog_days){
    if ($verbose){
        print "Changelog purge triggered for $changelog_days days.\n";
    }
    my $count = int $dbh->do(
        'DELETE FROM changelog
         WHERE stamp < date_sub(curdate(), interval ? day)',
        undef, $changelog_days);
    if ($verbose){
        print "$count records were deleted.\nDone with changelog purge.\n";
    }
}

exit(0);
