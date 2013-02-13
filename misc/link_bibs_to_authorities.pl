#!/usr/bin/env perl

use Koha;
use Koha::Bib;
use TryCatch;
use C4::Context;
use Getopt::Long;
use Parallel::ForkManager;
use DateTime::Format::Natural;
use Carp;

my $dtfn = DateTime::Format::Natural->new(time_zone => 'local');

$| = 1;

# command-line parameters
my $verbose   = 0;
my $test_only = 0;
my $want_help = 0;
my $workers   = 1;
my $since     = $dtfn->parse_datetime('1970-01-01 00:00:00');

my $result = GetOptions(
    'verbose'       => \$verbose,
    'test'          => \$test_only,
    'w|workers:i'   => \$workers,
    's|since:s'     =>
        sub { ($since) = $dtfn->parse_datetime_duration($_[1]) },
    'h|help'        => \$want_help
);

if (not $result or $want_help) {
    print_usage();
    exit 0;
}

my $num_bibs_processed = 0;
my $num_bibs_modified = 0;
my $num_bad_bibs = 0;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
my $forker = Parallel::ForkManager->new( $workers );
for (0..$workers-1) {
    next if $forker->start;
    $dbh = $C4::Context::context->{dbh} = C4::Context->dbh->clone;
    process_bibs($_, $workers, $since);
    $dbh->commit();
    $forker->finish;
}
$forker->wait_all_children;

exit 0;

sub process_bibs {
    my ($worker_number, $worker_count, $since) = @_;
    my $sql =
        'SELECT biblionumber FROM biblioitems '.
        'WHERE biblionumber % ? = ? '.
        '  AND timestamp >= ? '.
        'ORDER BY biblionumber ASC';
    my $sth = $dbh->prepare($sql);
    $sth->execute( $worker_count, $worker_number, $since );
    while (my ($biblionumber) = $sth->fetchrow_array()) {
        $num_bibs_processed++;
        try {
            process_bib($biblionumber);
        }
        catch ($e) {
            carp "Error processing bib $biblionumber: $e";
        }

        if (not $test_only and ($num_bibs_processed % 100) == 0) {
            print_progress_and_commit($num_bibs_processed);
        }
    }

    $dbh->commit unless $test_only;

    print <<_SUMMARY_;

Bib authority heading linking report
------------------------------------
Number of bibs checked:       $num_bibs_processed
Number of bibs modified:      $num_bibs_modified
Number of bibs with errors:   $num_bad_bibs
_SUMMARY_
}

sub process_bib {
    my $biblionumber = shift;

    my $bib = Koha::Bib->new( id=>$biblionumber );
    try {
        $bib->marc;
    }
    catch {
        print "\nCould not retrieve bib $biblionumber from the database - record is corrupt or not found.\n";
        $num_bad_bibs++;
        return;
    }

    my $headings_changed = $bib->relink_with_stubbing;

    if ($headings_changed) {   
        if ($verbose) {
            my $title = substr($bib->marc->title, 0, 20);
            print "Bib $biblionumber ($title): $headings_changed headings changed\n";
        }
        unless ($test_only) {
            $bib->save;
            $num_bibs_modified++;
        }
    }
}

sub print_progress_and_commit {
    my $recs = shift;
    $dbh->commit();
    print "... processed $recs records\n";
}

sub print_usage {
    print <<_USAGE_;
$0: link headings in bib records to authorities.

This batch job checks each bib record in the Koha
database and attempts to link each of its headings
to the matching authority record.

Parameters:
    --workers=N     Run N separate processing threads.
    --since=T       Only process bibs modified since T. Can take the
                    form of a date (e.g. "02/01/2013") or a duration
                    (e.g. "24 hours ago").
    --verbose       Print the number of headings changed for each bib.
    --test          Only test the authority linking and report the
                    results; do not change the bib records.
    --help or -h    Show this message.
_USAGE_
}
