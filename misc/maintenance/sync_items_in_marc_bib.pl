#!/usr/bin/perl

# Copyright 2011 LibLime, a Division of PTFS, Inc.
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
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Biblio;
use C4::Items;
use Getopt::Long;

$| = 1;

# command-line parameters
my $want_help = 0;
my $sync = 0;
my $remove_items = 0;

my $result = GetOptions(
    'sync'      => \$sync,
    'remove'    => \$remove_items,
    'h|help'    => \$want_help,
);

if (not $result or $want_help or (not $sync and not $remove_items)) {
    print_usage();
    exit 0;
}

my $num_bibs_processed     = 0;
my $num_bibs_modified      = 0;
my $num_marc_items_deleted = 0;
my $num_marc_items_added   = 0;
my $num_bad_bibs           = 0;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

our ($itemtag, $itemsubfield) = GetMarcFromKohaField("items.itemnumber", '');
our ($item_sth) = $dbh->prepare("SELECT itemnumber FROM items WHERE biblionumber = ?");

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
Number of item fields removed from bibs:  $num_marc_items_deleted
Number of item fields added to bibs:      $num_marc_items_added
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

    # delete any item tags
    foreach my $field ($bib->field($itemtag)) {
        unless ($bib->delete_field($field)) {
            warn "Could not delete item in $itemtag for biblionumber $biblionumber";
            next;
        }
        $num_marc_items_deleted++;
        $bib_modified = 1;
    }

    unless($remove_items){
        # add back items from items table
        $item_sth->execute($biblionumber);
        while (my $itemnumber = $item_sth->fetchrow_array) {
            my $marc_item = C4::Items::GetMarcItem($biblionumber, $itemnumber);
            unless ($marc_item) {
                warn "FAILED C4::Items::GetMarcItem for biblionumber=$biblionumber, itemnumber=$itemnumber";
                next;
            }
            foreach my $item_field ($marc_item->field($itemtag)) {
                $bib->insert_fields_ordered($item_field);
                $num_marc_items_added++;
                $bib_modified = 1;
            }
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

This script removes the item data embedded in the MARC bib
records (for indexing).  Optionally it will replace the embedded items
with the authoritative item data as stored in the items table.

If Zebra is used, run rebuild_zebra.pl -b -r after
running this script.

This script should be run when updating to LEK 4.000.010
from any previous version. As of this version, item data is
no longer stored in the MARC data, but only added dynamically when needed.

Parameters:
    --sync          synchronize embedded MARC data (deprecated use)
    --remove        remove embedded MARC data
    --help or -h            show this message.
_USAGE_
}
