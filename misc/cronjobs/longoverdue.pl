#!/usr/bin/env perl
#-----------------------------------
# Copyright 2008 LibLime
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

=head1 NAME

longoverdue.pl  cron script to set lost statuses on overdue materials.
                Execute without options for help.

=cut

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
use C4::Items;
use C4::LostItems;
use C4::Accounts;
use C4::Circulation;
use Getopt::Long;

my  ($lost_start, $longodue_start, $confirm, $debug, $verbose);

my $endrange = 366;  # FIXME hardcoded - don't deal with anything overdue by more than this num days.

GetOptions( 
    'lost=i'      => \$lost_start,
    'longoverdue=i' => \$longodue_start,
    'confirm'    => \$confirm,
    'verbose'    => \$verbose,
    'debug'      => \$debug,
);

my $usage = << 'ENDUSAGE';
longoverdue.pl : This cron script sets lost values on overdue items, charging the patron's account
for the item's replacement price for the value 'lost'.  It is designed to be run as a nightly job.
The command line options exist primarily for testing purposes.
Generally, parameters should be taken from the OverdueRules syspref.

This script takes the following parameters :

    --lost              integer, num days overdue to set to 'lost' and charge patron.

    --longoverdue       integer, num days overdue to set to 'longoverdue'.  Patron is not charged.

    --verbose | v       verbose.  (or use --debug for more)

    --confirm           confirm.  without this option, the script will report the number of affected items and
                        return without modifying any records.

  examples :
  $PERL5LIB/misc/cronjobs/longoverdue.pl --lost 30
    Would set LOST='lost' after 30 days (up to one year).  The account will be charged.

  $PERL5LIB/misc/cronjobs/longoverdue.pl --longoverdue 20 --lost 40
    Would set the item to longoverdue after 20 days, and lost after 40 days.

WARNING:  Flippant use of this script could set all or most of the items in your catalog to Lost and charge your
patrons for them!

ENDUSAGE

# FIXME: We need three pieces of data to operate:
#         ~ lower bound (number of days),
#         ~ upper bound (number of days),
#         ~ new lost value.
#        Right now we get only two, causing the endrange hack.  This is a design-level failure.
# FIXME: do checks on --lost ranges to make sure they are exclusive.
# FIXME: do checks on --lost ranges to make sure the authorized values exist.
# FIXME: do checks on --lost ranges to make sure don't go past endrange.
# FIXME: convert to using pod2usage
# FIXME: allow --help or -h
# 

$verbose = 1 if($debug);

if(!defined $longodue_start){
    if(C4::Context->preference("OverdueRules") =~ /longoverdue:(\d+)/){
        $longodue_start = $1;
    }
}
if(!defined $lost_start){
    if(C4::Context->preference("OverdueRules") =~ /lost:(\d+)/){
        $lost_start = $1;        
    }
}

if( $longodue_start && $longodue_start > $lost_start){
    print "Invalid overdue rules.\n" if $verbose;
    exit 1;
}

if( ! $lost_start && ! $longodue_start ){
    print "No lost settings specified.\n" if $verbose;
    exit;
}

unless ($confirm) {
    $verbose = 1;     # If you're not running it for real, then the whole point is the print output.
    print "### TEST MODE -- NO ACTIONS TAKEN ###\n";
}

# In my opinion, this line is safe SQL to have outside the API. --atz
our $bounds_sth = C4::Context->dbh->prepare("SELECT DATE_SUB(CURDATE(), INTERVAL ? DAY)");

sub bounds ($) {
    $bounds_sth->execute(shift);
    return $bounds_sth->fetchrow;
}

# FIXME - This sql should be inside the API.
sub longoverdue_sth {
    my $query = "
    SELECT issues.*,items.barcode,items.holdingbranch,items.homebranch,items.itemlost
      FROM issues, items
     WHERE items.itemnumber = issues.itemnumber
      AND  DATE_SUB(CURDATE(), INTERVAL ? DAY)  > issues.date_due
      AND  DATE_SUB(CURDATE(), INTERVAL ? DAY) <= issues.date_due
      AND  items.itemlost <> ?
     ORDER BY issues.date_due
    ";
    return C4::Context->dbh->prepare($query);
}

#FIXME - Should add a 'system' user and get suitable userenv for it for logging, etc.

my $count;
my @report;
my $total = 0;
my $i = 0;


my $sth_items = longoverdue_sth();

if($longodue_start){
    my $longodue_end = $lost_start || $endrange;
    my ($startdate) = bounds($longodue_end);  # yes, range is backwards from date.
    my ($enddate) = bounds($longodue_start);

    $verbose and printf "\nlongoverdue:\nDue %d - %d days ago (%s to %s), lost => longoverdue\n",
                    $longodue_start, $longodue_end, $startdate, $enddate;
    $sth_items->execute($longodue_start, $longodue_end, 'longoverdue');
    $count=0;
    while (my $row=$sth_items->fetchrow_hashref) {
        printf ("Due %s: item %d from borrower %d to lost: %s\n", $row->{date_due}, $row->{itemnumber}, $row->{borrowernumber}, 'longoverdue') if($debug);
        ModItemLost($row->{'biblionumber'}, $row->{'itemnumber'}, 'longoverdue') if $confirm;
        $count++;
    }
    push @report, {
       startrange => $longodue_end,
         endrange => $longodue_start,
            range => "$longodue_start - $longodue_end",
            date1 => $startdate,
            date2 => $enddate,
        lostvalue => 'longoverdue',
            count => $count,
    };
    $total += $count;
};
if($lost_start){
    my ($startdate) = bounds($endrange);
    my ($enddate) = bounds($lost_start);
    $verbose and 
        printf "\nlost:\nDue %d - %d days ago (%s to %s), lost => lost\n",
        $lost_start, $endrange, $startdate, $enddate;
    $sth_items->execute($lost_start, $endrange, 'lost');
    $count=0;
    while (my $row=$sth_items->fetchrow_hashref) {
        printf ("Due %s: item %d from borrower %d to lost: %s\n", $row->{date_due}, $row->{itemnumber}, $row->{borrowernumber}, 'lost') if($debug);
        if ($confirm){
            my $lost_id = C4::LostItems::CreateLostItem($row->{'itemnumber'}, $row->{'borrowernumber'});
            C4::Accounts::chargelostitem($lost_id);
            ModItemLost($row->{'biblionumber'}, $row->{'itemnumber'}, 'lost');
        }
        $count++;
    }
    push @report, {
       startrange => $endrange,
         endrange => $lost_start,
            range => "$lost_start - $endrange",
            date1 => $startdate,
            date2 => $enddate,
        lostvalue => 'lost',
            count => $count,
    };
    $total += $count;    
}

sub summarize ($$) {
    my $arg = shift;    # ref to array
    my $got_items = shift || 0;     # print "count" line for items
    my @report = @$arg or return undef;
    my $i = 0;
    for my $range (@report) {
        printf "\nDue %3s - %3s days ago (%s to %s), lost => %s\n",
            map {$range->{$_}} qw(startrange endrange date2 date1 lostvalue);
        $got_items and printf "  %4s items\n", $range->{count};
    }
}

print "\n### LONGOVERDUE SUMMARY ###";
summarize (\@report, 1);
print "\nTOTAL: $total items\n";
