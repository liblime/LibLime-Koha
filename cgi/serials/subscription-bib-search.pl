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


=head1 NAME

subscription-bib-search.pl

=head1 DESCRIPTION

this script search among all existing subscriptions.

=head1 PARAMETERS

=over 4

=item op
op use to know the operation to do on this template.
 * do_search : to search the subscription.

Note that if op = do_search there are some others params specific to the search :
    marclist,and_or,excluding,operator,value

=item startfrom
to multipage gestion.


=back

=cut


use strict;
use warnings;

use CGI;
use C4::Koha;
use C4::Auth;
use Koha;
use C4::Context;
use C4::Output;
use C4::Search;
use C4::Biblio;
use Koha::Solr::Service;
use Koha::Solr::Query;

my $input=new CGI;
# my $type=$query->param('type');
my $op = $input->param('op') || q{};
my $dbh = C4::Context->dbh;

my $startfrom=$input->param('startfrom');
$startfrom=0 unless $startfrom;
my ($template, $loggedinuser, $cookie);
my $resultsperpage;

my $query = $input->param('q');
# don't run the search if no search term !
if ($op eq "do_search" && $query) {

    # add the itemtype limit if applicable
    my $itemtypelimit = $input->param('itemtypelimit');
    if ( $itemtypelimit ) {
        $query .= " AND itemtype:$itemtypelimit";
    }

    $resultsperpage= $input->param('resultsperpage');
    $resultsperpage = 20 if(!defined $resultsperpage);

    my $solr = Koha::Solr::Service->new();
    my $q_param = {query => $query, rtype => 'bib'};
    $q_param->{options} = { start => ($startfrom*$resultsperpage) } if $startfrom;
    my ($results,$total_hits) = $solr->simpleSearch(Koha::Solr::Query->new($q_param), display => 1);

    my $total = scalar @$results;

    ($template, $loggedinuser, $cookie)
        = get_template_and_user({template_name => "serials/result.tmpl",
                query => $input,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => 1},
                flagsrequired => {catalogue => 1},
                debug => 1,
                });

    # multi page display gestion
    my $displaynext=0;
    my $displayprev=$startfrom;
    if(($total_hits - (($startfrom+1)*($resultsperpage))) > 0 ){
        $displaynext = 1;
    }


    my @numbers = ();

    if ($total_hits>$resultsperpage)
    {
        for (my $i=1; $i<$total/$resultsperpage+1; $i++)
        {
            if ($i<16)
            {
                my $highlight=0;
                ($startfrom==($i-1)) && ($highlight=1);
                push @numbers, { number => $i,
                    highlight => $highlight ,
                    searchdata=> $results,
                    startfrom => ($i-1)};
            }
        }
    }

    my $from = 0;
    $from = $startfrom*$resultsperpage+1 if($total_hits > 0);
    my $to;

    if($total_hits < (($startfrom+1)*$resultsperpage))
    {
        $to = $total_hits;
    } else {
        $to = (($startfrom+1)*$resultsperpage);
    }
    $template->param(
                            query => $query,
                            resultsloop => $results,
                            startfrom=> $startfrom,
                            displaynext=> $displaynext,
                            displayprev=> $displayprev,
                            resultsperpage => $resultsperpage,
                            startfromnext => $startfrom+1,
                            startfromprev => $startfrom-1,
                            total=>$total_hits,
                            from=>$from,
                            to=>$to,
                            numbers=>\@numbers,
                            );
} # end of if ($op eq "do_search" & $query)
 elsif ($op eq "do_search") {
    ($template, $loggedinuser, $cookie)
        = get_template_and_user({template_name => "serials/subscription-bib-search.tmpl",
                query => $input,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {catalogue => 1, serials=>1},
                debug => 1,
                });
    # load the itemtypes
    my $itemtypes = GetItemTypes;
    my @itemtypesloop;
    my $selected=1;
    my $cnt;
    foreach my $thisitemtype ( sort {$itemtypes->{$a}->{'description'} cmp $itemtypes->{$b}->{'description'} } keys %$itemtypes ) {
        my %row =(
                    code => $thisitemtype,
                    selected => $selected,
                    description => $itemtypes->{$thisitemtype}->{'description'},
                );
        $selected = 0 if ($selected) ;
        push @itemtypesloop, \%row;
    }
    $template->param(itemtypeloop => \@itemtypesloop);
    $template->param("no_query" => 1);
}
 else {
    ($template, $loggedinuser, $cookie)
        = get_template_and_user({template_name => "serials/subscription-bib-search.tmpl",
                query => $input,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {catalogue => 1, serials=>1},
                debug => 1,
                });
    # load the itemtypes
    my $itemtypes = GetItemTypes;
    my @itemtypesloop;
    my $selected=1;
    my $cnt;
    foreach my $thisitemtype ( sort {$itemtypes->{$a}->{'description'} cmp $itemtypes->{$b}->{'description'} } keys %$itemtypes ) {
        my %row =(
                    code => $thisitemtype,
                    selected => $selected,
                    description => $itemtypes->{$thisitemtype}->{'description'},
                );
        $selected = 0 if ($selected) ;
        push @itemtypesloop, \%row;
    }
    $template->param(itemtypeloop => \@itemtypesloop);
    $template->param("no_query" => 0);
}

# Print the page
output_html_with_http_headers $input, $cookie, $template->output;

# Local Variables:
# tab-width: 4
# End:
