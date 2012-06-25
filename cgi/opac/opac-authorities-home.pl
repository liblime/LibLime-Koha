#!/usr/bin/env perl
# WARNING: 4-character tab stops here

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

use CGI;
use C4::Auth;

use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::AuthoritiesMarc;
use C4::Koha;    # XXX subfield_is_koha_internal_p
use Koha::Solr::Service;
use Koha::Solr::Query;
use Koha::Pager;

my $query        = new CGI;
my $op           = $query->param('op') || '';
my $authtypecode = $query->param('authtypecode') || '';
my $dbh          = C4::Context->dbh;

my $start = $query->param('start') // 0;
my $authid    = $query->param('authid');
my $template_file = ($op eq 'do_search') ? "opac-authoritiessearchresultlist.tmpl" : "opac-authorities-home.tmpl";
my ( $template, $loggedinuser, $cookie )= get_template_and_user(
        {
            template_name   => $template_file,
            query           => $query,
            type            => 'opac',
            authnotrequired => 1,
            debug           => 1,
        }
    );
my $resultsperpage;

my $authtypes = getauthtypes;
my @authtypesloop;
$authtypecode = 'TOPIC_TERM' unless $authtypecode; # default search type.

foreach my $thisauthtype ( sort { $authtypes->{$a}{'authtypetext'} cmp $authtypes->{$b}{'authtypetext'} } keys %$authtypes ){
    next unless $thisauthtype; # There should be no default authority types.
    my $selected = 1 if $thisauthtype eq $authtypecode;
    my %row = (
        value        => $thisauthtype,
        selected     => $selected,
        authtypetext => $authtypes->{$thisauthtype}{'authtypetext'},
    );
    push @authtypesloop, \%row;
}

if ( $op eq "do_search" ) {

    my $idx = $query->param('idx');
    my $q = $query->param('q');
    my $sortby = $query->param('orderby');
    my $query_string = ($idx eq 'auth-heading')? 'auth-heading:' : 'auth-full:';
    $query_string .= $q;
    my $options = { 'sort' => $sortby, 'fq' => "kauthtype_s:$authtypecode" };
    $options->{start} = $start if $start;
    my $solr = Koha::Solr::Service->new();
    my $solr_query = Koha::Solr::Query->new( {query => $query_string, options => $options, rtype => 'auth', opac => 1} );

    my $rs = $solr->search($solr_query->query,$solr_query->options);

    my $resultset = ($rs->is_error) ? '' : $rs->content;
    my $results = [];

    for my $doc (@{$resultset->{response}->{docs}}){
        my $record = MARC::Record->new_from_xml($doc->{marcxml},'utf8','MARC21'); 
        my $summary = C4::AuthoritiesMarc::BuildSummary($record,undef,$authtypecode);
        push @$results, {   summary => $summary,
                            authid => $doc->{authid},
                            authtype => $doc->{kauthtype_s},
                            used => C4::AuthoritiesMarc::CountUsage($doc->{authid}),

                        };
    }
    my $resultsperpage;
    my $total = $resultset->{'response'}->{'numFound'};

    my $pager = Koha::Pager->new({pageset => $rs->pageset, offset_param => 'start'});

    $template->param(   result          => $results,
                        orderby         => $sortby,
                        total           => $total,
                        authtypecode    => $authtypecode,
                        pager           => $pager->tmpl_loop(),
                        from            => $pager->first,
                        to              => $pager->last(),
    );

}

$template->param( authtypesloop => \@authtypesloop );

# Print the page
output_html_with_http_headers $query, $cookie, $template->output;

# Local Variables:
# tab-width: 4
# End:
