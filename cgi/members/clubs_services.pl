#!/usr/bin/env perl
use strict;

use CGI;

use C4::Output;
use C4::Search;
use C4::Auth;
use C4::Koha;
use C4::Members;
use C4::ClubsAndServices;

my $query = new CGI;

my $borrowernumber = $query->param('borrowernumber');

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/clubs_services.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {borrow => 1},
			     debug => 1,
			     });

# get borrower information ....
my $borrowerData = GetMemberDetails( $borrowernumber );
$template->param(
  borrowernumber => $borrowernumber,
  surname => $borrowerData->{'surname'},
  firstname => $borrowerData->{'firstname'},
  cardnumber => $borrowerData->{'cardnumber'},
  address => $borrowerData->{'address'},
  city => $borrowerData->{'city'},
  phone => $borrowerData->{'phone'},
  email => $borrowerData->{'email'},
  categorycode => $borrowerData->{'categorycode'},
  categoryname => $borrowerData->{'description'},
  branchcode => $borrowerData->{'branchcode'},
  branchname => C4::Branch::GetBranchName($borrowerData->{'branchcode'}),
);
                                                


if ( $query->param('action') eq 'cancel' ) { ## Cancel the enrollment in the passed club or service
  CancelClubOrServiceEnrollment( $query->param('caseId') );
}

## Get the borrowers current clubs & services
my $enrolledClubsAndServices = GetEnrolledClubsAndServices( $borrowernumber );
$template->param( enrolledClubsAndServicesLoop => $enrolledClubsAndServices );

## Get clubs & services the borrower can enroll in from the Intranet
my $enrollableClubsAndServices = GetAllEnrollableClubsAndServices( $borrowernumber, $query->cookie('branch') );
$template->param( enrollableClubsAndServicesLoop => $enrollableClubsAndServices );

output_html_with_http_headers $query, $cookie, $template->output;

