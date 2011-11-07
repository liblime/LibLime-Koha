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
    = get_template_and_user({template_name => "members/clubs_services_enroll.tmpl",
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
                        

if ( $query->param('action') eq 'enroll' ) { ## We were passed the necessary fields from the enrollment page.
  my $casId = $query->param('casId');
  my $casaId = $query->param('casaId');
  my $data1 = $query->param('data1');
  my $data2 = $query->param('data2');
  my $data3 = $query->param('data3');
            
  my $dateEnrolled; # Will default to Today
              
  my ( $success, $errorCode, $errorMessage ) = EnrollInClubOrService( $casaId, $casId, '', $dateEnrolled, $data1, $data2, $data3, '', $borrowernumber  );
                
  $template->param(
    previousActionEnroll => 1,
  );
                            
  if ( $success ) {
    $template->param( enrollSuccess => 1 );
  } else {
    $template->param( enrollFailure => 1 );
    $template->param( failureMessage => $errorMessage );
  }
                                              
} elsif ( DoesEnrollmentRequireData( $query->param('casaId') ) ) { ## We were not passed any data, and the service requires extra data
  my ( $casId, $casaId, $casTitle, $casDescription, $casStartDate, $casEndDate, $casTimestamp ) = GetClubOrService( $query->param('casId') );
  my ( $casaId, $casaType, $casaTitle, $casaDescription, $casaPublicEnrollment,
       $casData1Title, $casData2Title, $casData3Title,
       $caseData1Title, $caseData2Title, $caseData3Title,
       $casData1Desc, $casData2Desc, $casData3Desc,
       $caseData1Desc, $caseData2Desc, $caseData3Desc,
       $timestamp )= GetClubOrServiceArchetype( $casaId );
  $template->param(
                  casId => $casId,
                  casTitle => $casTitle,
                  casDescription => $casDescription,
                  casStartDate => $casStartDate,
                  casEndDate => $casEndDate,
                  casTimeStamp => $casTimestamp,
                  casaId => $casaId,
                  casaType => $casaType,
                  casaTitle => $casaTitle,
                  casaDescription => $casaDescription,
                  casaPublicEnrollment => $casaPublicEnrollment,

                  borrowernumber => $borrowernumber,
                  );

  if ( $caseData1Title ) {
    $template->param( caseData1Title => $caseData1Title );
  }
  if ( $caseData2Title ) {
    $template->param( caseData2Title => $caseData2Title );
  }
  if ( $caseData3Title ) {
    $template->param( caseData3Title => $caseData3Title );
  }
  
  if ( $caseData1Desc ) {
    $template->param( caseData1Desc => $caseData1Desc );
  }
  if ( $caseData2Desc ) {
    $template->param( caseData2Desc => $caseData2Desc );
  }
  if ( $caseData3Desc ) {
    $template->param( caseData3Desc => $caseData3Desc );
  }
      
} else { ## We were not passed any data, but the enrollment does not require any

  my $casId = $query->param('casId');
  my $casaId = $query->param('casaId');
            
  my $dateEnrolled; # Will default to Today
              
  my ( $success, $errorCode, $errorMessage ) = EnrollInClubOrService( $casaId, $casId, '', $dateEnrolled, '', '', '', '', $borrowernumber  );
                
  $template->param(
    previousActionEnroll => 1,
  );
                            
  if ( $success ) {
    $template->param( enrollSuccess => 1 );
  } else {
    $template->param( enrollFailure => 1 );
    $template->param( failureMessage => $errorMessage );
  }


}
output_html_with_http_headers $query, $cookie, $template->output;

