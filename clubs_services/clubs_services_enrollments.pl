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
    = get_template_and_user({template_name => "clubs_services/clubs_services_enrollments.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 1,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

my $casId = $query->param('casId');
my ( $casId, $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $last_updated, $branchcode ) 
  = GetClubOrService( $casId );
$template->param( casTitle => $title );

my $enrollments = GetCasEnrollments( $casId );
$template->param( enrollments_loop => $enrollments );

$template->param(
                intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
                intranetstylesheet => C4::Context->preference("intranetstylesheet"),
                IntranetNav => C4::Context->preference("IntranetNav"),
                );
                                                                                                
output_html_with_http_headers $query, $cookie, $template->output;
