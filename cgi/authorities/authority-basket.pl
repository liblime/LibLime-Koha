#!/usr/bin/env perl

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
use CGI;
use C4::Koha;
use C4::Biblio;
use C4::Items;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Members::Lists;
use Koha::Authority;
use TryCatch;
use Carp;

my $query = CGI->new;

my ($template, $loggedinuser, $cookie) = get_template_and_user(
  {
    template_name => "authorities/authority-basket.tmpl",
    query => $query,
    type => "intranet",
    authnotrequired => 0,
    flagsrequired => {editauthorities => 1},
    debug => 1,
  }
);

my $authority_list     = $query->param('authority_list');
my @authorities = split( /\//, $authority_list );

my $op = $query->param('op') // '';
if ( $op eq 'merge' ) {
    my $authIdparent = $query->param('authIdparent');
    my $keeper = Koha::Authority->new(id => $authIdparent);

    for my $authid (grep {$_ ne $authIdparent} $query->param('authid')) {
        try {
            $keeper->absorb( Koha::Authority->new(id=>$authid) )
        } catch ($e) {
            carp "Error absorbing auth_$authid: $e";
        }
    }

    print
        qq{Content-Type: text/html\n\n<html><body onload="window.close()"></body></html>};
    exit;
}

my @results;
for my $authid ( @authorities ) {
    try {
        my $auth = Koha::Authority->new( id => $authid );
        push @results, {
            summary => [$auth->summary],
            rcn => $auth->rcn,
            authid => $auth->id,
            authtype => $auth->typecode,
            used => $auth->link_count,
        };
    } catch ($e) {
        carp "Error retrieving auth_$authid: $e";
    }
}
$template->param( result => \@results );

output_html_with_http_headers $query, $cookie, $template->output;
