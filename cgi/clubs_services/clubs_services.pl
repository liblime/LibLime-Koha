#!/usr/bin/env perl
use strict;
use CGI;
use C4::Output;
use C4::Auth;
use Koha;
use C4::Context;
use C4::ClubsAndServices;

my $query = new CGI;
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "clubs_services/clubs_services.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 1,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

my $branchcode = C4::Context->userenv->{branch};

my $clubs = GetClubsAndServices( 'club', $branchcode );
my $services = GetClubsAndServices( 'service', $branchcode );

$template->param(
                intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
                intranetstylesheet => C4::Context->preference("intranetstylesheet"),
                IntranetNav => C4::Context->preference("IntranetNav"),

                clubs_services => 1,
                                  
                clubsLoop => $clubs,
                servicesLoop => $services,
                );
                                                                                                
output_html_with_http_headers $query, $cookie, $template->output;
