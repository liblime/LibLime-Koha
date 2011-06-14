#!/usr/bin/env perl

# Copyright 2010 Ian Walls and ByWater Solutions
#
# This script is intended to help Koha libraries affected by Bug 4201 repair
# their holds priorities before patching to fix the bug.  
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This script is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA



# In regular mode, this script searches the reserves table for all holds where 
# the priorities are damaged, i.e. there exists a priority number greater than 
# the total number of holds for that biblio.  In Aggressive mode, all holds are 
# selected.  For each selected biblio, all the holds are reprioritized first by 
# reservedate, then the existing priority number.  It is fully possible this may
# be counter to the intent of priority list; the user is warned.



# modules to use
use Getopt::Long;
use Koha;
use C4::Context;

# Benchmarking/testing variables
my $startime = time();
my $usecount = 0;
my $testmode;
my $aggressive;

GetOptions(
  't'	=> \$testmode,
  'a|aggressive' => \$aggressive
);

# output log
open(OUT, ">bug4201cleanup.csv") || die ("Cannot open report file");

print OUT "--------Log for Bug4201 cleanup script--------\n";
print OUT "--------TEST REPORT---------------------------\n" if (defined $testmode);
print OUT "Biblionumber, Borrowernumber, Reserve Date, Old Priority, New Priority\n";

# fetch biblionumbers for titles with a hold priority greater than the number of total holds
my $dbh = C4::Context->dbh;
my $query = "SELECT biblionumber, ";
if (defined $aggressive) {
  $query .= "count(priority) as countp FROM reserves GROUP BY biblionumber HAVING countp > 1";
} else {
  $query .= "max(priority) as maxp, min(priority) as minp, count(priority) as countp FROM reserves GROUP BY biblionumber HAVING maxp > countp AND minp > 0";
}
my $sth = $dbh->prepare($query);
$sth->execute();

# loop through each found biblionumber
while (@row = $sth->fetchrow_array()){
  my $biblionumber = $row[0];
  my $new_priority = 1;
  
  # select all the holds associated with the biblionumber
  my $sth2 = $dbh->prepare("SELECT borrowernumber, reservedate, priority FROM reserves WHERE found is null AND biblionumber = ? ORDER BY reservedate asc, priority asc");
  $sth2->execute($biblionumber);
  # loop through all holds for that biblio, ordered by reservedate, old_priority
  while (@row2 = $sth2->fetchrow_array()){
    my $borrowernumber = $row2[0];
    my $reservedate    = $row2[1];
    my $old_priority   = $row2[2];
    
    if ($old_priority ne $new_priority){
      # Update the priority value from old to new, matching on the biblionumber/borrowernumber primary key 
      my $sth3 = $dbh->prepare("UPDATE reserves SET priority = ? WHERE biblionumber = ? AND borrowernumber = ? AND found is null");
      $sth3->execute($new_priority, $biblionumber, $borrowernumber) unless (defined $testmode);
      $usecount++;
    } 

    print OUT "$biblionumber, $borrowernumber, $reservedate, $old_priority, $new_priority\n";
  
    # increment new priority number on the way out of the loop
    $new_priority++;  
  }
  # line to visually break up different biblios in log
  print OUT "--------\n"
}
# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records found to modify. Took $time seconds\n" if (defined $testmode);

