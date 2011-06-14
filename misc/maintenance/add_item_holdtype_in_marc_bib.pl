#!/usr/bin/env perl

use strict;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Koha;
use C4::Context;
use C4::Biblio;
use C4::Items;
use Getopt::Long;
use MARC::Field;

$| = 1;

# command-line parameters
my $want_help = 0;
my $sync = 0;

my $result = GetOptions(
    'sync'      => \$sync,
    'h|help'    => \$want_help,
);

if (not $result or $want_help or (not $sync)) {
    print_usage();
    exit 0;
}

my $num_bibs_processed;
my $num_bibs_modified;
my $num_942r_fields_deleted;
my $num_942r_fields_added;
my $num_bad_bibs;
my $table;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

my $bibliotag      = '942';
my $bibliosubfield = 'r';
my $holdtype       = 'item';

process_bibs();
$dbh->commit();

exit 0;

sub process_bibs {

    foreach $table ("subscription","periodicals") { 
      $num_bibs_processed      = 0;
      $num_bibs_modified       = 0;
      $num_942r_fields_deleted = 0;
      $num_942r_fields_added   = 0;
      $num_bad_bibs            = 0;
      my $sql = "SELECT biblionumber FROM biblio WHERE biblionumber IN (SELECT biblionumber FROM $table)";
      my $sth = $dbh->prepare($sql);
      $sth->execute();
      while (my ($biblionumber) = $sth->fetchrow_array()) {
          $num_bibs_processed++;
          process_bib($biblionumber);

          if (($num_bibs_processed % 100) == 0) {
              print_progress_and_commit($num_bibs_processed,$table);
          }
      }
  
      $dbh->commit;

      print <<_SUMMARY_;

Addition of 942\$r to records in $table table
---------------------------------------------
Number of bibs checked:                   $num_bibs_processed
Number of bibs modified:                  $num_bibs_modified
Number of 942r fields removed from bibs:  $num_942r_fields_deleted
Number of 942r fields added to bibs:      $num_942r_fields_added
Number of bibs with errors:               $num_bad_bibs
_SUMMARY_
    }
}

sub process_bib {
    my $biblionumber = shift;

    my $bib = GetMarcBiblio($biblionumber);
    unless (defined $bib) {
        print "\nCould not retrieve bib $biblionumber from the database - record is corrupt.\n";
        $num_bad_bibs++;
        return;
    }

    my $bib_modified = 0;

    # delete any 942$r tags
    foreach my $field ($bib->field($bibliotag)) {
        unless ($bib->field($bibliotag)->delete_subfield(code => $bibliosubfield)) {
            next;
        }
        $num_942r_fields_deleted++;
        $bib_modified = 1;
    }

    # add hold type of item
    if ($bib->field('942')) {
      $bib->field('942')->add_subfields('r' => $holdtype);
      $num_942r_fields_added++;
      $bib_modified = 1;
    }
    else {
      $bib->append_fields(MARC::Field->new('942',' ',' ','r' => $holdtype));
      $num_942r_fields_added++;
      $bib_modified = 1;
    }

    if ($bib_modified) {
        ModBiblioMarc($bib, $biblionumber, GetFrameworkCode($biblionumber));
        $num_bibs_modified++;
    }

}

sub print_progress_and_commit {
    my $recs = shift;
    my $table = shift;
    $dbh->commit();
    print "... processed $recs records in $table table\n";
}

sub print_usage {
    print <<_USAGE_;
$0: synchronize item data embedded in MARC bibs

This script adds the 942\$r MARC data subfield
with a hold type of item for records in the 
subscription and periodicals tables.

Parameters:
    --sync         update serial controlled MARC 942\$r subfields to item level
    --help or -h   show this message.
_USAGE_
}
