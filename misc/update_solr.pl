#!/usr/bin/env perl

use strict;

use Koha;
use C4::Context;
use Getopt::Long;
use File::Temp qw/ tempdir /;
use File::Path;
use C4::Biblio;
use C4::Items;
#use C4::AuthoritiesMarc;
#use Business::ISBN;
#use Unicode::Normalize;
use Try::Tiny;
use bytes;
use File::Slurp;

use Koha::Solr::Service;
use Koha::Solr::IndexStrategy::MARC;
use Koha::Solr::Document::MARC;

#my $indexdefs = read_file('/opt/build/koha/LibLime-Koha/etc/solr/biblio-index.rules');
my $indexdefs = read_file(C4::Context->config('solr')->{biblio_rules});
my $docgen = Koha::Solr::IndexStrategy::MARC->new(rules_text => $indexdefs);

my $biblios;
my $authorities;
my $want_help;
my $use_solrqueue;
my $verbose;
my $export_dir;
my $test;
my $do_not_clear;

my $kb_per_post = 200;

my $result = GetOptions(
    'b'             => \$biblios,
    'a'             => \$authorities,
    'h|help'        => \$want_help,
    'q'             => \$use_solrqueue,
    'v|verbose'     => \$verbose,
    'e:s'           => \$export_dir,
    's'             => \$kb_per_post,
    't|test'        => \$test,
    'k|keep'        => \$do_not_clear,
);

if (not $result or $want_help) {
    print_usage();
    exit 0;
}
if (not $biblios and not $authorities) {
    my $msg = "Must specify -b or -a to index bibs or authorities.  Otherwise, this script will do nothing.\n";
    $msg   .= "Please do '$0 --help' to see usage.\n";
    die $msg;
}

my $dbh = C4::Context->dbh;

my $UPDATE = 'update';
my $SOFTDELETE = 'softDelete';

# We can write out to a file or just post to solr server.

my $solr = new Koha::Solr::Service;

if($biblios){
    # Get all updates. 
    # Note this script does not handle deletes or soft-deletes.
    # They should happen immediately.  Soft-deletes should be trivial
    # since the html shouldn't need to be regenerated.  The only update
    # should be setting the deleted field.  (which we no longer need to store in marc).
    #my $sth = $dbh->prepare("SELECT record_id from solrqueue where done=0 and operation=?");
    
    my $sth;
    if ($use_solrqueue) {
        $sth = $dbh->prepare("SELECT biblio_auth_number from zebraqueue where done=0 and operation=?");
        $sth->execute($UPDATE);
    } else {
        # full reindex; delete all.
        !$test && !$do_not_clear && clear_bibs();
        $sth = $dbh->prepare("SELECT biblionumber from biblio where biblionumber>=28692"); # TODO: Add deleted records.
        $sth->execute();
    }

    my $num_exported = 0;
    mkdir "$export_dir" unless (-d $export_dir);
    my $outfilename = "$export_dir/koha.xml";
    #my $mode = (-e $outfilename) ? ">>:utf8" : ">:utf8";
    my $mode = ">:utf8";
    open (OUT, $mode, $outfilename) or die $!;

    my $cur_filesize = 0;
    my @docs_to_post = ();
    
    my $post_each = 0;
    use Time::Elapse;
    Time::Elapse->lapse(my $now); 
    while (my ($bibno) = $sth->fetchrow_array) {
        # eval {}

        my $record = C4::Items::GetMarcWithItems($bibno);
        #warn $record->as_formatted();
        my $doc = Koha::Solr::Document::MARC->new(record => $record, strategy => $docgen);
        #warn $doc;
        $cur_filesize += bytes::length($doc);
        $verbose && warn $cur_filesize;
        push @docs_to_post, $doc;
        if($export_dir){
            print OUT "$doc\n";
        }
        if (!$test && $cur_filesize/1024 > $kb_per_post || $post_each){
            post_to_solr(\@docs_to_post);
            $num_exported += scalar(@docs_to_post);
            @docs_to_post = ();
            $cur_filesize = 0;
            $verbose && warn "Posted $num_exported docs";
        }
    }
    post_to_solr(\@docs_to_post) unless($test);
    $num_exported += scalar(@docs_to_post);
    say "Posted $num_exported docs to solr in $now";
    say "Tried to save the solr docs at $outfilename";
}

sub post_to_solr{
    my $docs = shift;
    $verbose && warn "Posting to solr.";
    my $rv = $solr->add($docs);
    warn $rv;

}

sub clear_bibs {
    my $rs = $solr->delete({ query => "*:*" });
}

1;
