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
    = get_template_and_user({template_name => "clubs_services/edit_archetypes.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

my $branchcode = C4::Context->userenv->{branch};

## Create new Archetype
if ( $query->param('action') eq 'create' ) {
  my $type = $query->param('type');
  my $title = $query->param('title');
  my $description = $query->param('description');
  my $publicEnrollment = $query->param('publicEnrollment');
  if ( $publicEnrollment eq 'yes' ) {
    $publicEnrollment = 1;
  } else {
    $publicEnrollment = 0;
  }

  my $casData1Title = $query->param('casData1Title');
  my $casData2Title = $query->param('casData2Title');
  my $casData3Title = $query->param('casData3Title');

  my $caseData1Title = $query->param('caseData1Title');
  my $caseData2Title = $query->param('caseData2Title');
  my $caseData3Title = $query->param('caseData3Title');

  my $casData1Desc = $query->param('casData1Desc');
  my $casData2Desc = $query->param('casData2Desc');
  my $casData3Desc = $query->param('casData3Desc');

  my $caseData1Desc = $query->param('caseData1Desc');
  my $caseData2Desc = $query->param('caseData2Desc');
  my $caseData3Desc = $query->param('caseData3Desc');

  my $caseRequireEmail = $query->param('caseRequireEmail');

  my ( $createdSuccessfully, $errorCode, $errorMessage ) = AddClubOrServiceArchetype( 
                                                             $type, 
                                                             $title, 
                                                             $description, 
                                                             $publicEnrollment, 
                                                             $casData1Title, 
                                                             $casData2Title, 
                                                             $casData3Title, 
                                                             $caseData1Title, 
                                                             $caseData2Title, 
                                                             $caseData3Title, 
                                                             $casData1Desc, 
                                                             $casData2Desc, 
                                                             $casData3Desc, 
                                                             $caseData1Desc, 
                                                             $caseData2Desc, 
                                                             $caseData3Desc,
                                                             $caseRequireEmail,
                                                             $branchcode 
                                                           );
  
  $template->param(
    previousActionCreate => 1,
    createdTitle => $title,
  );
  
  if ( $createdSuccessfully ) {
    $template->param( createSuccess => 1 );
  } else {
    $template->param( createFailure => 1);
    $template->param( failureMessage => $errorMessage );
  }

}

## Delete an Archtype
elsif ( $query->param('action') eq 'delete' ) {
  my $casaId = $query->param('casaId');
  my $success = DeleteClubOrServiceArchetype( $casaId );

  $template->param( previousActionDelete => 1 );
  if ( $success ) {
    $template->param( deleteSuccess => 1 );
  } else {
    $template->param( deleteFailure => 1 );
  }
}

## Edit a club or service: grab data, put in form.
elsif ( $query->param('action') eq 'edit' ) {
  my $casaId = $query->param('casaId');
  my ( $casaId, $type, $title, $description, $publicEnrollment, 
       $casData1Title, $casData2Title, $casData3Title, 
       $caseData1Title, $caseData2Title, $caseData3Title, 
       $casData1Desc, $casData2Desc, $casData3Desc, 
       $caseData1Desc, $caseData2Desc, $caseData3Desc, 
       $caseRequireEmail, $casaTimestamp, $casaBranchcode ) = GetClubOrServiceArchetype( $casaId );

  $template->param(
      previousActionEdit => 1,
      editCasaId => $casaId,
      editType => $type,
      editTitle => $title,
      editDescription => $description,
      editCasData1Title => $casData1Title,
      editCasData2Title => $casData2Title,
      editCasData3Title => $casData3Title,
      editCaseData1Title => $caseData1Title,
      editCaseData2Title => $caseData2Title,
      editCaseData3Title => $caseData3Title,
      editCasData1Desc => $casData1Desc,
      editCasData2Desc => $casData2Desc,
      editCasData3Desc => $casData3Desc,
      editCaseData1Desc => $caseData1Desc,
      editCaseData2Desc => $caseData2Desc,
      editCaseData3Desc => $caseData3Desc,
      editCaseRequireEmail => $caseRequireEmail,
      editCasaTimestamp => $casaTimestamp,
      editCasaBranchcode => $casaBranchcode
  );
  
  if ( $publicEnrollment ) {
    $template->param( editPublicEnrollment => 1 );
  }
}

# Update an Archetype
elsif ( $query->param('action') eq 'update' ) {
  my $casaId = $query->param('casaId');
  my $type = $query->param('type');
  my $title = $query->param('title');
  my $description = $query->param('description');
  my $publicEnrollment = $query->param('publicEnrollment');
  if ( $publicEnrollment eq 'yes' ) {
    $publicEnrollment = 1;
  } else {
    $publicEnrollment = 0;
  }

  my $casData1Title = $query->param('casData1Title');
  my $casData2Title = $query->param('casData2Title');
  my $casData3Title = $query->param('casData3Title');

  my $caseData1Title = $query->param('caseData1Title');
  my $caseData2Title = $query->param('caseData2Title');
  my $caseData3Title = $query->param('caseData3Title');

  my $casData1Desc = $query->param('casData1Desc');
  my $casData2Desc = $query->param('casData2Desc');
  my $casData3Desc = $query->param('casData3Desc');

  my $caseData1Desc = $query->param('caseData1Desc');
  my $caseData2Desc = $query->param('caseData2Desc');
  my $caseData3Desc = $query->param('caseData3Desc');

  my $caseRequireEmail = $query->param('caseRequireEmail');

  my ( $createdSuccessfully, $errorCode, $errorMessage ) = 
    UpdateClubOrServiceArchetype( 
      $casaId, $type, $title, $description, $publicEnrollment, 
      $casData1Title, $casData2Title, $casData3Title, 
      $caseData1Title, $caseData2Title, $caseData3Title, 
      $casData1Desc, $casData2Desc, $casData3Desc, 
      $caseData1Desc, $caseData2Desc, $caseData3Desc,
      $caseRequireEmail
    );
  
  $template->param(
    previousActionUpdate => 1,
    updatedTitle => $title,
  );
  
  if ( $createdSuccessfully ) {
    $template->param( updateSuccess => 1 );
  } else {
    $template->param( updateFailure => 1);
    $template->param( failureMessage => $errorMessage );
  }

}
                                                        

my $clubArchetypes = GetClubsAndServicesArchetypes( 'club' );
my $serviceArchetypes = GetClubsAndServicesArchetypes( 'service' );

$template->param(
		intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
		intranetstylesheet => C4::Context->preference("intranetstylesheet"),
		IntranetNav => C4::Context->preference("IntranetNav"),

		edit_archetypes => 1,
		
		clubArchetypesLoop => $clubArchetypes,
		serviceArchetypesLoop => $serviceArchetypes,
		);

output_html_with_http_headers $query, $cookie, $template->output;
