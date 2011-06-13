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
    = get_template_and_user({template_name => "clubs_services/enroll_clubs_services.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 1,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

my $branchcode = $query->cookie('branch');

if ( $query->param('action') eq 'enroll' ) {
  my $borrowerBarcode = $query->param('borrowerBarcode');
  my $casId = $query->param('casId');
  my $casaId = $query->param('casaId');
  my $data1 = $query->param('data1');
  my $data2 = $query->param('data2');
  my $data3 = $query->param('data3');

  my $dateEnrolled; # Will default to Today
  
  my ( $success, $errorCode, $errorMessage ) = EnrollInClubOrService( $casaId, $casId, $borrowerBarcode, $dateEnrolled, $data1, $data2, $data3, $branchcode );

  $template->param(
    previousActionEnroll => 1,
    enrolledBarcode => $borrowerBarcode,
  );

  if ( $success ) {
    $template->param( enrollSuccess => 1 );
  } else {
    $template->param( enrollFailure => 1 );
    $template->param( failureMessage => $errorMessage );
  }
  
}

my ( $casId, $casaId, $casTitle, $casDescription, $casStartDate, $casEndDate, $casTimestamp ) = GetClubOrService( $query->param('casId') );
my ( $casaId, $casaType, $casaTitle, $casaDescription, $casaPublicEnrollment,
     $casData1Title, $casData2Title, $casData3Title,
     $caseData1Title, $caseData2Title, $caseData3Title,
     $casData1Desc, $casData2Desc, $casData3Desc,
     $caseData1Desc, $caseData2Desc, $caseData3Desc,
     $timestamp )= GetClubOrServiceArchetype( $casaId );

$template->param(
                intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
                intranetstylesheet => C4::Context->preference("intranetstylesheet"),
                IntranetNav => C4::Context->preference("IntranetNav"),
                                  
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
                                                                                                
output_html_with_http_headers $query, $cookie, $template->output;
