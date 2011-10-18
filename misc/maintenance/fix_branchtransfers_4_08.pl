#!/usr/bin/env perl 

## Copyright 2011 LibLime/PTFS, Inc.
##
## Script to fix legacy branchtransfers data that treated the table as a historic table.
## Under LLK 4.8+, code treats transfer of item as unique: you can only transfer one
## item at a time.

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

my $table = 'branchtransfers';
my $fx    = 0;
my $dbh   = C4::Context->dbh;
my $sth;
_rightdb();
_createTmp();
_uniqueLines();
_syncItems();
exit;

#######################################################################
sub _syncItems {
   print "Syncing holdingbranch and tobranch... \n";
   my $ln = 0;
   $fx = 0;
   $sth = $dbh->prepare("SELECT br.*,items.holdingbranch,items.homebranch
      FROM $table br, items
     WHERE br.itemnumber = items.itemnumber
       AND br.tobranch <> items.holdingbranch");
   $sth->execute();
   while(my $row = $sth->fetchrow_hashref()) {
      $$row{datearrived} ||= '';
      print "   item $$row{itemnumber}, to=$$row{tobranch}, holding=$$row{holdingbranch}, arrived=$$row{datearrived}, ";
      if (!$$row{datearrived}) { # hasn't arrived, so set item based on branchtransfers
         $dbh->do("UPDATE items
            SET holdingbranch = ?
          WHERE itemnumber = ?",undef,
            $$row{tobranch},
            $$row{itemnumber}
         );
         print "resetting item's holdingbranch to $$row{tobranch}\n";
         $fx++;
      }
      else {
         print "already arrived but at wrong place (probably old), removing from table\n";
         $dbh->do("DELETE FROM $table WHERE itemnumber=?",undef,$$row{itemnumber});
         $fx++;
      }
   }
   print "   $fx rows updated.\n";
}

sub _uniqueLines {
   my %br = ();
   print "Handling duplicate rows, ignoring comments... ";
   $sth = $dbh->prepare("SELECT COUNT(itemnumber) FROM $table
      GROUP BY itemnumber HAVING COUNT(itemnumber)>1");
   $sth->execute();
   my($cnt) = $sth->fetchrow_array || 0;
   $sth = $dbh->prepare("SELECT COUNT(*) FROM $table");
   $sth->execute();
   my($total) = $sth->fetchrow_array;
   print "$cnt rows with multiple entries, $total total rows in table\n";
   if (!$cnt) { return }

   print "Below, *=skipping this row: \n";
   my $ln = 0;
   $sth = $dbh->prepare("SELECT * FROM $table ORDER BY datesent DESC");
   $sth->execute();
   while(my $row = $sth->fetchrow_hashref()) {
      if($ln>=72) { $ln=0; print "\n"; }
      if ($br{$$row{itemnumber}}) {
         print '*';
      }
      else {
         $br{$$row{itemnumber}} = $row;
         $dbh->do("INSERT INTO tmp_$table (itemnumber,datesent,frombranch,datearrived,tobranch)
            VALUES(?,?,?,?,?)",undef,
            $$row{itemnumber},
            $$row{datesent},
            $$row{frombranch},
            $$row{datearrived},
            $$row{tobranch}
         );
         $fx++;
         print '.';
      }
      $ln++;
   }
   print "\n   $fx unique rows found, copying from tmp_$table to $table...\n";
   $dbh->do("TRUNCATE $table");
   $dbh->do("INSERT INTO $table SELECT * FROM tmp_$table");
}

sub _createTmp {
   print "Creating temporary table `tmp_$table`...\n";
   $dbh->do("DROP TABLE IF EXISTS `tmp_$table`");
   $sth = $dbh->prepare("SHOW CREATE TABLE $table");
   $sth->execute();
   my($sql) = ($sth->fetchrow_array)[1];
   $sql =~ s/$table/tmp_$table/sg;
   $dbh->do($sql);
   $dbh->do("UPDATE tmp_$table SET comments = NULL");
}

sub _rightdb {
   my $dbstr = C4::Context->config('database') . ' ' 
          . C4::Context->config('user') . '@' 
          . C4::Context->config('hostname');
   print "Running against database $dbstr.\n";
   print "Is this correct?  [YES=Continue |no] ";
   my $ok = <STDIN>; chomp $ok;
   if ($ok eq '' || $ok =~ /y/i) {}
   else { print "Exiting.\n"; exit }
}

