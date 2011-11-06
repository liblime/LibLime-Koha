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

use C4::Auth;
use C4::Koha;
use C4::Circulation;
use C4::Reserves;
use C4::Members;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Dates qw/format_date/;  
use C4::Letters;
use C4::Branch; # GetBranches  
use C4::ClubsAndServices;

my $query = new CGI;

my ($template, $borrowernumber, $cookie)
    = get_template_and_user({template_name => "opac-clubsAndServices-enroll.tmpl",
                             query => $query,
                             type => "opac",
                             authnotrequired => 0,
                             flagsrequired => {borrow => 1},
                             debug => 1,
                             });

# get borrower information ....
my ( $borr ) = GetMemberDetails( $borrowernumber );

$borr->{'dateenrolled'} = format_date( $borr->{'dateenrolled'} );
$borr->{'expiry'}       = format_date( $borr->{'expiry'} );
$borr->{'dateofbirth'}  = format_date( $borr->{'dateofbirth'} );
$borr->{'ethnicity'}    = fixEthnicity( $borr->{'ethnicity'} );


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

$template->param( clubs_services => 1 );

output_html_with_http_headers $query, $cookie, $template->output;
