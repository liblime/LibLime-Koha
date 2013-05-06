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

use CGI;
use Koha;
use Koha::Authority;
use Koha::HeadingMap;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Koha;    # XXX subfield_is_koha_internal_p
use Koha::Solr::Service;
use Koha::Solr::Query;
use Koha::Pager;
use TryCatch;
use Carp;

my $query = CGI->new;
my $q = $query->param('q');

my $start = $query->param('start') || 0;

my $template_file = ($q) ? "opac-authoritiessearchresultlist.tmpl" : "opac-authorities-home.tmpl";
my ( $template, $loggedinuser, $cookie )= get_template_and_user(
        {
            template_name   => $template_file,
            query           => $query,
            type            => 'opac',
            authnotrequired => 1,
            debug           => 0,
        }
    );

if ( $q ) {
    my $options = {};
    $options->{sort} = 'auth-heading-sort '
        . (($query->param('orderby') ~~ 'AZ') ? 'asc' : 'desc');

    if ($query->param('typecodes')) {
        $options->{fq} = sprintf('kauthtype_s:(%s)',
                     join(' OR ', map {qq("$_")} split(/\|/, $query->param('typecodes'))));
    }

    $options->{start} = $query->param('start') || 0;

    my $query_string = qq{auth-heading:($q)};

    my $solr = Koha::Solr::Service->new();
    my $solr_query = Koha::Solr::Query->new(
        query => $query_string, options => $options, rtype => 'auth', opac => 1 );

    my $rs = $solr->search($solr_query->query,$solr_query->options);

    my $resultset = ($rs->is_error) ? {} : $rs->content;
    my $results = [];

    for my $doc (@{$resultset->{response}{docs}}) {
        my $authid = $doc->{authid};
        try {
            my $auth = Koha::Authority->new(id => $authid);
            die 'Unlinked authority' unless $auth->is_linked;

            push @$results, {
                summary => [$auth->summary],
                authid => $authid,
                rcn => $auth->rcn,
                used => $auth->link_count,
                authtype => $auth->type->{summary},
            };
        }
        catch ($e) {
            chomp($e);
            carp "Error processing authority $authid: $e;";
        }
    }

    my $pager = Koha::Pager->new(
        pageset => $rs->pageset(
            entries_per_page => 20, current_page=> int($start/20)+1),
        offset_param => 'start');

    $template->param(   result          => $results,
                        total           => $resultset->{response}{numFound},
                        pager           => $pager->tmpl_loop(),
                        from            => $pager->first,
                        to              => $pager->last(),
    );
}

output_html_with_http_headers $query, $cookie, $template->output;
