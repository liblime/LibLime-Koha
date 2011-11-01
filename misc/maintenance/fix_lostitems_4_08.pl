#!/usr/bin/env perl

## Copyright 2011 LibLime/PTFS, Inc.
## This script removes orphan lines in the lost_items table that
## should no longer be linked to the patron because the item is
## believed to be found.

use strict;
use warnings;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin qw($RealBin);
    eval { require "$RealBin/../kohalib.pl" };
    if(@!) { die $! }
}

use C4::Koha;
use C4::Context;

my $fx  = 0;
my $dbh = C4::Context->dbh;
my $sth;

my $dbstr = C4::Context->config('database') . ' ' 
          . C4::Context->config('user') . '@' 
          . C4::Context->config('hostname');
print "Running against database $dbstr.\n";
print "Is this correct?  [YES=Continue |no] ";
my $ok = <STDIN>; chomp $ok;
if ($ok eq '' || $ok =~ /^y/i) {}
else { print "Exiting.\n"; exit }
print "Actually update data?  [YES |no=report only] ";
$ok = <STDIN>; chomp $ok;
if ($ok eq '' || $ok =~ /^y/i) { $ok=1 }
else                           { $ok=0 }

my @av = @{C4::Koha::GetAuthorisedValues('LOST') // []};

print "Fixing items not lost still linked to patrons in lost_items table...\n";
$sth = $dbh->prepare("SELECT li.* 
   FROM lost_items li, items
  WHERE li.itemnumber = items.itemnumber
    AND items.itemlost = 0");
$sth->execute();
while(my $row = $sth->fetchrow_hashref()) {
   my $unlink = 0;

   ## has this borrower ever been charged for this item?
   my $sth1 = $dbh->prepare("SELECT * FROM accountlines
      WHERE itemnumber = ?
        AND borrowernumber = ?
        AND accounttype = 'L'");
   $sth1->execute($$row{itemnumber},$$row{borrowernumber});
   my $charged = $sth1->fetchrow_hashref();
   if ($charged) {
      my $trycredit = 0;
      print "$$row{itemnumber} charged to $$charged{borrowernumber} but no longer lost\n";
      print "   Seeing if item is currently issued... ";
      $sth1 = $dbh->prepare("SELECT borrowernumber FROM issues WHERE itemnumber=?");
      $sth1->execute($$row{itemnumber});
      my($boriss) = $sth1->fetchrow_array;
      if ($boriss) {
         print "yes\n";
         if ($boriss == $$row{borrowernumber}) {
            print "   Currently checked out by same patron that lost item...\n";
            print "   Seeing if item was found via accountlines description... ";
            if ($$charged{description} =~ /found \d\d/) {
               print "was found\n";
               $unlink = 1;
            }
            else {
               print "probably not found. Setting items.itemlost\n";
               $dbh->do("UPDATE items SET itemlost=1 WHERE itemnumber=?",undef,$$row{itemnumber})
                  if $ok;
               $fx++;
            }
         }
         else {
            print "   Currently checked out by a patron different from the one who lost the item\n";
            $unlink = 1;
            $trycredit = 1;
         }
      }
      else {
         print "no: skipping\n";
      }
   }
   else {
      print "$$row{itemnumber} never charged to $$row{borrowernumber}: removing from lost_items table\n";
      $unlink = 1;
   }

   if ($unlink) {
      $dbh->do("DELETE FROM lost_items
            WHERE itemnumber     = ?
              AND borrowernumber = ?",undef,
         $$row{itemnumber},$$row{borrowernumber}) if $ok;
      $fx++;
   }
}

printf("$fx rows %s\nDone.\n", $ok? 'updated' : 'found');
exit;
