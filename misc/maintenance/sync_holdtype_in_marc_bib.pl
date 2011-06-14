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

my $num_bibs_processed      = 0;
my $num_bibs_modified       = 0;
my $num_942r_fields_deleted = 0;
my $num_942r_fields_added   = 0;
my $num_bad_bibs            = 0;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

our ($bibliotag, $bibliosubfield) = GetMarcFromKohaField("biblio.holdtype", '');
our ($biblio_sth) = $dbh->prepare("SELECT holdtype FROM biblio WHERE biblionumber = ?");

process_bibs();
$dbh->commit();

exit 0;

sub process_bibs {
    my $sql = "SELECT biblionumber FROM biblio ORDER BY biblionumber ASC";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my ($biblionumber) = $sth->fetchrow_array()) {
        $num_bibs_processed++;
        process_bib($biblionumber);

        if (($num_bibs_processed % 100) == 0) {
            print_progress_and_commit($num_bibs_processed);
        }
    }

    $dbh->commit;

    print <<_SUMMARY_;

Embedded item synchronization report
------------------------------------
Number of bibs checked:                   $num_bibs_processed
Number of bibs modified:                  $num_bibs_modified
Number of item fields removed from bibs:  $num_942r_fields_deleted
Number of item fields added to bibs:      $num_942r_fields_added
Number of bibs with errors:               $num_bad_bibs
_SUMMARY_
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
            warn "Could not delete subfield $bibliosubfield in $bibliotag for biblionumber $biblionumber";
            next;
        }
        $num_942r_fields_deleted++;
        $bib_modified = 1;
    }

    # add back holdtype from biblio.holdtype
    $biblio_sth->execute($biblionumber);
    while (my $holdtype = $biblio_sth->fetchrow_array) {
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
    }

    if ($bib_modified) {
        ModBiblioMarc($bib, $biblionumber, GetFrameworkCode($biblionumber));
        $num_bibs_modified++;
    }

}

sub print_progress_and_commit {
    my $recs = shift;
    $dbh->commit();
    print "... processed $recs records\n";
}

sub print_usage {
    print <<_USAGE_;
$0: synchronize item data embedded in MARC bibs

This script removes the 942\$r MARC data and replaces it
with the authoritative biblio.holdtype value.

Parameters:
    --sync          synchronize embedded MARC data (deprecated use)
    --help or -h            show this message.
_USAGE_
}
