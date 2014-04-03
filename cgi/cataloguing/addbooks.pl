#!/usr/bin/env perl


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

=head1 cataloguing:addbooks.pl

	TODO

=cut

use strict;
use warnings;
use CGI;
use C4::Auth;
use C4::Biblio;
use C4::Breeding;
use C4::Output;
use C4::Koha;
use C4::Search;
use C4::Circulation;

use URI::Escape;

my $input = new CGI;

my $success = $input->param('biblioitem');
my $query   = $input->param('q');
my @value   = $input->param('value');
my $page    = $input->param('page') || 1;
my $results_per_page = 20;


my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "cataloguing/addbooks.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => '*' },
        debug           => 1,
    }
);

# get framework list
my $frameworks = getframeworks;
my @frameworkcodeloop;
foreach my $thisframeworkcode ( keys %{$frameworks} ) {
    push @frameworkcodeloop, {
        value         => $thisframeworkcode,
        frameworktext => $frameworks->{$thisframeworkcode}->{'frameworktext'},
    };
}


# Searching the catalog.
if ($query) {
   ## special case for barcode suffixes: expand to use active library's prefix
   my $expandedBarcode = '';
   if (C4::Context->preference('itembarcodelength') && $query !~ /\D/) {
      my $originalQ = $query;
      $expandedBarcode = C4::Circulation::barcodedecode(barcode=>$originalQ);
      $query = "barcode:$expandedBarcode OR biblionumber:$query";
      if ((length($originalQ)==13) || (length($originalQ)==10)) {
         $query .= " OR isbn:$originalQ";
      }
   }
    # find results
    my $offset = $results_per_page * ($page - 1);
    #my ( $error, $marcresults, $total_hits ) = SimpleSearch($query, $offset, $results_per_page);
    my $solr = Koha::Solr::Service->new();
    my $q_param = {query => $query, rtype => 'bib'};
    $q_param->{options} = { start => $offset } if $offset;
    my ($results,$hits) = $solr->simpleSearch(Koha::Solr::Query->new($q_param), display => 1);

    # format output
    # SimpleSearch() give the results per page we want, so 0 offet here
    my $total = scalar @$results;

   # try to find exact match and warp speed to Edit Items
   foreach my $result(@$results) {
       next unless $result->{barcode};
      my(@barcodes) = split(/\s*\|\s*/,$$result{barcode});
      foreach my $i(0..$#barcodes) {
         if ($barcodes[$i] eq $expandedBarcode) { # exact search match on barcode
            my @inums = split(/\s*\|\s*/, $$result{itemnumber});
            print $input->redirect('additem.pl?biblionumber='
            . $$result{biblionumber}.'&op=edititem&itemnumber='
            . $inums[$i].'#edititem'
            );
            exit;
         }
      }
   }

    # Potentially modify query contained within quotes for URL purposes
    my $url_query = "/cgi-bin/koha/cataloguing/addbooks.pl?q=" . uri_escape($query) . "\&";
    $template->param(
        total          => $hits,
        query          => $query,
        resultsloop    => $results,
        #TODO: replace pagination_bar with Koha::Pager
        pagination_bar => pagination_bar( $url_query, getnbpages( $hits, $results_per_page ), $page, 'page' ),
    );

}

# fill with books in breeding farm

my $countbr = 0;
my @resultsbr;
if ($query) {
# fill isbn or title, depending on what has been entered
#u must do check on isbn because u can find number in beginning of title
#check is on isbn legnth 13 for new isbn and 10 for old isbn
    my ( $title, $isbn );
    if ($query=~/\d/) {
        my $querylength = length $query;
        if ( $querylength == 13 || $querylength == 10 ) {
            $isbn = $query;
        }
    }
    if (!$isbn) {
        # Potentially modify query contained within quotes for SQL purposes
        $title = ($query =~ s/\"//gr);
    }
    ( $countbr, @resultsbr ) = BreedingSearch( $title, $isbn );
}

my $breeding_loop = [];
for my $resultsbr (@resultsbr) {
    push @{$breeding_loop}, {
        id               => $resultsbr->{import_record_id},
        isbn             => $resultsbr->{isbn},
        copyrightdate    => $resultsbr->{copyrightdate},
        editionstatement => $resultsbr->{editionstatement},
        file             => $resultsbr->{file_name},
        title            => $resultsbr->{title},
        author           => $resultsbr->{author},
    };
}

$template->param(
    frameworkcodeloop => \@frameworkcodeloop,
    breeding_count    => $countbr,
    breeding_loop     => $breeding_loop,
);

output_html_with_http_headers $input, $cookie, $template->output;

