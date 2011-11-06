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

my $query = new CGI;

my ($template, $loggedinuser, $cookie) = get_template_and_user(
  {
    template_name => "members/borrower-basket.tmpl",
    query => $query,
    type => "intranet",
    authnotrequired => 0,
    flagsrequired => {borrowers => 1},
    debug => 1,
  }
);

if ( $query->param('op') eq 'add_to_list' ) {
  my $vars = $query->Vars;
  
  my $list_id = $vars->{'list_id'};
  
  unless ( $list_id ) {
    my $list_name = $vars->{'list_name'};
    $list_id = CreateList({ list_name => $list_name });
  }
  
  foreach my $key ( keys %$vars ) {
    if ( $key =~ m/^borrower/ ) {
      my $borrowernumber = $vars->{$key};
        AddBorrowerToList({
          list_id => $list_id,
          borrowernumber => $borrowernumber
        });    
    }
  }
}

my $borrower_list     = $query->param('borrower_list');
my $print_basket = $query->param('print');
my $verbose      = $query->param('verbose');

if ($verbose)      { $template->param( verbose      => 1 ); }
if ($print_basket) { $template->param( print_basket => 1 ); }

my @borrowers = split( /\//, $borrower_list );
my @results;

my $num = 1;

foreach my $borrowernumber ( @borrowers ) {
    $num++;
    my $borrower = GetMember( $borrowernumber, 'borrowernumber' );
    push( @results, $borrower );
}

$template->param(
    borrowers_loop => \@results,
    borrower_list => $query->param('borrower_list'),
);

$template->param( BorrowerListsLoop => GetLists() );

output_html_with_http_headers $query, $cookie, $template->output;
