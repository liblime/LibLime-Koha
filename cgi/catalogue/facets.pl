#!/usr/bin/env perl

# Copyright 2012 PTFS
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


use Koha;
use C4::Context;
use C4::Output 3.02 qw(:html :ajax);
use Koha::Solr::Service;
use Koha::Solr::Query;
use JSON;

my $cgi = CGI->new();


#FIXME : This script is essentially identical to the staff-side counterpart.
#  Should have just one facet script, with url routing handled by plack.

my $MOREFACET_COUNT = 20;

if (is_ajax()) {

    my $solr = new Koha::Solr::Service;
    my $facet_field = $cgi->param('facet');
    my $fq = $cgi->param('solr_fq');
    my $offset = $cgi->param('offset');
    # TODO: Allow facet ordering.  Will have to pull all ccode/itype/branch facets and resort here on display value,
    # which is why it's skipped it for now.
    my $solr_options = {
                    "fq"            => $fq,
                    "facet.field"   => $facet_field,
                    "facet.offset"  => $offset,
                    "rows"          => 0,
                    "spellcheck"    => "false",
                    "facet.limit"   => $MOREFACET_COUNT,
                  };
    my $solr_query = Koha::Solr::Query->new({query => $cgi->param('solr_query'), opac => 0, rtype => 'bib', options => $solr_options });

    my $rs = $solr->search($solr_query->query,$solr_query->options);
    
    my $output = {};
    
    if(!$rs->is_error){
        my $results = $rs->content;
        my $facets = $rs->koha_facets($MOREFACET_COUNT); # FIXME: this value is set
        my $response = $facets->[0]->{'values'} // {};
        
        print $cgi->header('application/json');
        printf "%s\n", to_json($response, {pretty => 0});
    
    } else {
        use DDP;
        warn p $rs;
        print $cgi->header('application/json');
        printf "%s\n", to_json( { error => 1 }, {pretty => 0});

    }
} else {
    print $cgi->redirect('/cgi-bin/koha/errors/404.pl');
    exit;
}

