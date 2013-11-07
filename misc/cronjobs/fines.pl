#!/usr/bin/env perl

#  This script loops through each overdue item, determines the fine,
#  and updates the total amount of fines due by each user.  It relies on
#  the existence of /tmp/fines, which is created by ???
# Doesnt really rely on it, it relys on being able to write to /tmp/
# It creates the fines file
#
#  This script is meant to be run nightly out of cron.

# Copyright 2000-2002 Katipo Communications
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

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/kohalib.pl" };
}

use Date::Calc qw/Date_to_Days/;

use Koha;
use C4::Context;
use C4::Circulation;
use C4::Overdues;
use C4::Calendar qw();  # don't need any exports from Calendar
use C4::Biblio;
use C4::Members qw(GetMember);
use C4::Debug;  # supplying $debug and $cgi_debug
use Getopt::Long;

my $spoof  = '';
my $help = 0;
my $verbose = 0;
my $output_dir;

GetOptions( 'h|help'        => \$help,
            'v|verbose'     => \$verbose,
            'o|out:s'       => \$output_dir,
            'd|spoof:s'     => \$spoof,
       );
my $usage = << 'ENDUSAGE';

This script calculates and Accrues estimated overdue fines
to patron accounts.  The fines are charged at checkin.

This script has the following parameters :
    -h --help: this message
    -o --out:  ouput directory for logs (defaults to env or /tmp if !exist)
    -v --verbose
    -d --date: spoof a date other than today, ISO format YYYY-MM-DD

ENDUSAGE

die $usage if $help;

use vars qw(@borrower_fields @item_fields @other_fields);
use vars qw($fldir $libname $delim $dbname $today $today_iso $today_days);
use vars qw($filename);

CHECK {
    @borrower_fields = qw(cardnumber categorycode surname firstname email phone address citystate);
        @item_fields = qw(itemnumber barcode date_due itemlost);
       @other_fields = qw(days_overdue fine);
    $libname = C4::Context->preference('LibraryName');
    $dbname  = C4::Context->config('database');
    $delim   = "\t"; # ?  C4::Context->preference('delimiter') || "\t";

}

INIT {
    $debug and print "Each line will contain the following fields:\n",
        "From borrowers : ", join(', ', @borrower_fields), "\n",
        "From items : ", join(', ', @item_fields), "\n",
        "Per overdue: ", join(', ', @other_fields), "\n",
        "Delimiter: '$delim'\n";
}

# Truncate fees_accruing 
# Without this, if Koha were to fail to remove an accruing fine
# when an item was made no longer overdue, the estimated fee would persist indefinitely.

C4::Overdues::ClearAccruingFines();

my $data = Getoverdues();
my $overdueItemsCounted = 0;
my %calendars = ();
$today = C4::Dates->new();
if ($spoof =~ /^\d{4}-\d\d-\d\d$/) {
    $today = C4::Dates->new($spoof,'iso');
}
$today_iso = $today->output('iso');
$today_days = Date_to_Days(split(/-/,$today_iso));

if($output_dir){
    $fldir = $output_dir if( -d $output_dir );
} else {
    $fldir = $ENV{TMPDIR} || "/tmp";
}
if (!-d $fldir) {
    warn "Could not write to $fldir ... does not exist!";
}
$filename = $dbname;
$filename =~ s/\W//;
$filename = $fldir . '/'. $filename . '_' .  $today_iso . ".log";
print "writing to $filename\n" if $verbose;
open (FILE, ">$filename") or die "Cannot write file $filename: $!";
print FILE join $delim, (@borrower_fields, @item_fields, @other_fields);
print FILE "\n";

for (my $i=0; $i<scalar(@$data); $i++) {
    my $datedue = C4::Dates->new($data->[$i]->{'date_due'},'iso');
    my $datedue_days = Date_to_Days(split(/-/,$datedue->output('iso')));
    my $due_str = $datedue->output();
    unless (defined $data->[$i]->{'borrowernumber'}) {
        print STDERR "ERROR in Getoverdues line $i: issues.borrowernumber IS NULL.  Repair 'issues' table now!  Skipping record.\n";
        next;   # Note: this doesn't solve everything.  After NULL borrowernumber, multiple issues w/ real borrowernumbers can pile up.
    }
    unless (defined $data->[$i]->{'itemnumber'}) {
        print STDERR "ERROR in Getoverdues line $i: issues.itemnumber IS NULL.  Repair 'issues' table now!  Skipping record.\n";
        next;   # Note: this doesn't solve everything.  After NULL borrowernumber, multiple issues w/ real borrowernumbers can pile up.
    }
    # for legacy data that doesn't set issuingbranch:
    $data->[$i]->{issuingbranch} ||= $data->[$i]->{branchcode};
    my $borrower = GetMember($data->[$i]->{'borrowernumber'});
    my $branchcode = C4::Circulation::GetCircControlBranch(
         pickup_branch        => $data->[$i]->{branchcode},
         item_homebranch      => $data->[$i]->{homebranch},
         item_holdingbranch   => $data->[$i]->{holdingbranch},
         borrower_branch      => $borrower->{branchcode},
    );
   # In final case, CircControl must be PickupLibrary. (branchcode comes from issues table here).
    my $calendar;
    unless (defined ($calendars{$branchcode})) {
        $calendars{$branchcode} = C4::Calendar->new(branchcode => $branchcode);
    }
    $calendar = $calendars{$branchcode};
    my $isHoliday = $calendar->isHoliday(split '/', $today->output('metric'));
      
    ($datedue_days <= $today_days) or next; # or it's not overdue, right?

    $overdueItemsCounted++;
    my ($daycounttotal, $amount,$daycount,$ismax);

	# Don't update the fine if today is a holiday.  
  	
	if (! $isHoliday ) {
        ($amount,$daycounttotal,$daycount,$ismax) = CalcFine($data->[$i], $borrower->{'categorycode'}, $branchcode, $today, $calendar);
		C4::Overdues::AccrueFine($data->[$i]->{id},$amount) if( $amount > 0 ) ;
 	}
    my @cells = ();
    push @cells, map {$borrower->{$_} // ''} @borrower_fields;
    push @cells, map {$data->[$i]->{$_} // ''} @item_fields;
    push @cells, $daycounttotal // '';
    push @cells, $amount // '';
    print FILE join($delim, @cells), "\n";
}

my $numOverdueItems = scalar(@$data);
if ($verbose) {
   print <<EOM;
Fines assessment -- $today_iso -- Saved to $filename
Number of Overdue Items:
     counted $overdueItemsCounted
    reported $numOverdueItems

EOM
}

close FILE;
