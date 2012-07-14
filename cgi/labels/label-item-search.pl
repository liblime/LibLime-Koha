#!/usr/bin/env perl
#
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
use warnings;
use vars qw($debug $cgi_debug);

use CGI;
use List::Util qw( max min );
use POSIX qw(ceil);

use C4::Auth qw(get_template_and_user);
use C4::Output qw(output_html_with_http_headers);
use Koha;
use C4::Context;
use C4::Dates;
#use C4::Search qw(SimpleSearch);
use C4::Biblio qw(TransformMarcToKoha);
use C4::Items qw(GetItemInfosOf get_itemnumbers_of);
use C4::Koha qw(GetItemTypes);    # XXX subfield_is_koha_internal_p
use C4::Labels::Lib qw(html_table);
use C4::Debug;

use Koha::Solr::Service;
use Koha::Solr::Query;

BEGIN {
    $debug = $debug || $cgi_debug;
    if ($debug) {
        require Data::Dumper;
        import Data::Dumper qw(Dumper);
    }
}

my $query = new CGI;

my $type      = $query->param('type');
my $op        = $query->param('op') || '';
my $batch_id  = $query->param('batch_id');
my $user_query = $query->param('user_query');
my $startfrom = $query->param('startfrom') || 1;
my ($template, $loggedinuser, $cookie) = (undef, undef, undef);
my (
    $total_hits,  $orderby, $results,  $total,  $error,
    $marcresults, $idx,     $datefrom, $dateto, $q
);
my $resultsperpage = C4::Context->preference('numSearchResults') || '20';
my $show_results = 0;
my $display_columns = [ {_add                   => {label => "Add Item", link_field => 1}},
                        {_item_call_number      => {label => "Call Number", link_field => 0}},
                        {_date_accessioned      => {label => "Accession Date", link_field => 0}},
                        {_barcode               => {label => "Barcode", link_field => 0}},
                        {select                 => {label => "Select", value => "_item_number"}},
                      ];

if ( $op eq "do_search" ) {
    $idx         = $query->param('idx');
    $q = $query->param('q');
    if ( $idx ) {
        $user_query = "$idx:($q)";
    } elsif ($q) {
        $user_query = $q;
    } #else from query->param

    $datefrom = $query->param('datefrom');
    $dateto   = $query->param('dateto');

    ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "labels/result.tmpl",
            query           => $query,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { borrowers => '*' },
            flagsrequired   => { catalogue => 1 },
            debug           => 1,
        }
    );

    if($datefrom || $dateto){
        $datefrom = "*" unless $datefrom;
        $dateto = "*" unless $dateto;
        $query .= " AND acqdate:[$datefrom TO $dateto]";
    }

    my $offset = $startfrom > 1 ? $startfrom - 1 : 0;
   # ( $error, $marcresults, $total_hits ) = SimpleSearch( $user_query, $offset, $resultsperpage );
    my $solr = Koha::Solr::Service->new();
    my $q_param = {query => $user_query, rtype => 'bib'};
    $q_param->{options} = {start => $offset} if($offset);
    ($results,$total_hits) = $solr->simpleSearch(Koha::Solr::Query->new($q_param) );
    if (scalar($results) > 0) {
        $show_results = scalar @$results;
    }
    else {
        $debug and warn "ERROR label-item-search: no results from SimpleSearch";

        # leave $show_results undef
    }
}

if ($show_results) {
    my $hits = $show_results;
    my @results_set = ();
    my @items =();
    # This code needs to be refactored using these subs...
    #my @items = &GetItemsInfo( $biblio->{biblionumber}, 'intra' );
    #my $dat = &GetBiblioData( $biblio->{biblionumber} );
   
    my $fdate = my $tdate = 0;
    my $ge = my $le = '';
    my $cq = $query->param('user_query');
    if ($cq) {
       ($fdate) = $cq =~ /ge=(\d{4}\-\d\d\-\d\d)/;
       ($tdate) = $cq =~ /le=(\d{4}\-\d\d\-\d\d)/;
    }
    else {
       if ($datefrom) { $fdate = $datefrom->output('iso')}
       if ($dateto)   { $tdate = $dateto->output('iso')  }
    }
    $fdate =~ s/\D//g;
    $tdate =~ s/\D//g;

    for ( my $i = 0 ; $i < $hits ; $i++ ) {
        my $marcrecord = ($results->[$i]->{marcxml}) ?
                MARC::Record->new_from_xml($results->[$i]->{marcxml}) : C4::Biblio::GetMarcBiblio($results->[$i]->{biblionumber}) ;
        my @row_data= ();
        #DEBUG Notes: Decode the MARC record from each resulting MARC record...
        #my $marcrecord = MARC::Record->new_from_xml($marcresults->[$i],'UTF-8',C4::Context->preference('marcflavour'));
        #DEBUG Notes: Transform it to Koha form...
        my $biblio = TransformMarcToKoha( C4::Context->dbh, $marcrecord, '' );
        #DEBUG Notes: Stuff the bib into @biblio_data...
        push (@results_set, $biblio);
        my $biblionumber = $biblio->{'biblionumber'};
        #DEBUG Notes: Grab the item numbers associated with this MARC record...
        my $itemnums = get_itemnumbers_of($biblionumber);
        #DEBUG Notes: Retrieve the item data for each number...
        if (my $iii = $itemnums->{$biblionumber}) {
            my $item_results = GetItemInfosOf(@$iii);

            ITEM:
            foreach my $item ( keys %$item_results ) {
                #DEBUG Notes: Build an array element 'item' of the correct bib (results) hash which contains item-specific data...
                if ($item_results->{$item}->{'biblionumber'} eq $results_set[$i]->{'biblionumber'}) {
                    my $item_data;
                    my $adate = $item_results->{$item}->{dateaccessioned};
                    $adate =~ s/\D//g;
                    if ($fdate) { next ITEM if $adate < $fdate }
                    if ($tdate) { next ITEM if $adate > $tdate }

                    $item_data->{'_item_number'} = $item_results->{$item}->{'itemnumber'};
                    $item_data->{'_item_call_number'} = ($item_results->{$item}->{'itemcallnumber'} ? $item_results->{$item}->{'itemcallnumber'} : 'NA');
                    $item_data->{'_date_accessioned'} = $item_results->{$item}->{'dateaccessioned'};
                    $item_data->{'_barcode'} = ( $item_results->{$item}->{'barcode'} ? $item_results->{$item}->{'barcode'} : 'NA');
                    $item_data->{'_add'} = $item_results->{$item}->{'itemnumber'};
                    unshift (@row_data, $item_data);    # item numbers are given to us in descending order by get_itemnumbers_of()...
                }
            }
            $results_set[$i]->{'item_table'} = html_table($display_columns, \@row_data);
        }
        else {
            # FIXME: Some error trapping code needed
            warn sprintf('No item numbers retrieved for biblio number: %s', $biblionumber);
        }
    }

    ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "labels/result.tmpl",
            query           => $query,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { borrowers => 1 },
            flagsrequired   => { catalogue => 1 },
            debug           => 1,
        }
    );

    # build page nav stuff.
    my ( @field_data, @numbers );
    $total = $total_hits;

    my ( $from, $to, $startfromnext, $startfromprev, $displaynext,
        $displayprev );

    if ( $total > $resultsperpage ) {
        my $num_of_pages = ceil( $total / $resultsperpage + 1 );
        for ( my $page = 1 ; $page < $num_of_pages ; $page++ ) {
            my $startfrm = ( ( $page - 1 ) * $resultsperpage ) + 1;
            push @numbers,
              {
                number    => $page,
                startfrom => $startfrm
              };
        }

        $from          = $startfrom;
        $startfromprev = $startfrom - $resultsperpage;
        $startfromnext = $startfrom + $resultsperpage;

        $to =
            $startfrom + $resultsperpage > $total
          ? $total
          : $startfrom + $resultsperpage - 1;

        # multi page display
        $displaynext = 0;
        $displayprev = $startfrom > 1 ? $startfrom : 0;

        $displaynext = 1 if $to < $total_hits;

    }
    else {
        $displayprev = 0;
        $displaynext = 0;
    }

    $template->param(
        total          => $total_hits,
        from           => $from,
        to             => $to,
        startfromnext  => $startfromnext,
        startfromprev  => $startfromprev,
        startfrom      => $startfrom,
        displaynext    => $displaynext,
        displayprev    => $displayprev,
        resultsperpage => $resultsperpage,
        numbers        => \@numbers,
    );

    $template->param(
        results   => ($show_results ? 1 : 0),
        result_set=> \@results_set,
        batch_id  => $batch_id,
        type      => $type,
        idx       => $idx,
        user_query => $user_query,
    );
}

#
#   search section
#

else {
    ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name   => "labels/search.tmpl",
            query           => $query,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { catalogue => 1 },
            debug           => 1,
        }
    );
    my $itemtypes = GetItemTypes;
    my @itemtypeloop;
    foreach my $thisitemtype ( keys %$itemtypes ) {
        my %row = (
            value       => $thisitemtype,
            description => $itemtypes->{$thisitemtype}->{'description'},
        );
        push @itemtypeloop, \%row;
    }
    $template->param(
        itemtypeloop => \@itemtypeloop,
        batch_id     => $batch_id,
        type         => $type,
    );

}

# Print the page
$template->param( DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(), );
output_html_with_http_headers $query, $cookie, $template->output;
