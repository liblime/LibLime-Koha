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
    = get_template_and_user({template_name => "clubs_services/edit_clubs_services.tmpl",
			     query => $query,
			     type => "intranet",
			     authnotrequired => 1,
			     flagsrequired => {parameters => 1},
			     debug => 1,
			     });

my $branchcode = C4::Context->userenv->{branch};

# Archetype selected for Club or Service creation
if ( $query->param('action') eq 'selectArchetype' ) {
  my $casaId = $query->param('casaId');

  my ( $casaId, $casaType, $casaTitle, $casaDescription, $casaPublicEnrollment, 
       $casData1Title, $casData2Title, $casData3Title, 
       $caseData1Title, $caseData2Title, $caseData3Title, 
       $casData1Desc, $casData2Desc, $casData3Desc, 
       $caseData1Desc, $caseData2Desc, $caseData3Desc, 
       $casaTimestamp ) = GetClubOrServiceArchetype( $casaId );

  $template->param(
    previousActionSelectArchetype => 1,
    
    casaId => $casaId, 
    casaType => $casaType, 
    casaTitle => $casaTitle, 
    casaDescription => $casaDescription, 
    casaPublicEnrollment => $casaPublicEnrollment, 
    casData1Title => $casData1Title, 
    casData2Title => $casData2Title, 
    casData3Title => $casData3Title, 
    caseData1Title => $caseData1Title, 
    caseData2Title => $caseData2Title, 
    caseData3Title => $caseData3Title, 
    casData1Desc => $casData1Desc, 
    casData2Desc => $casData2Desc, 
    casData3Desc => $casData3Desc, 
    caseData1Desc => $caseData1Desc, 
    caseData2Desc => $caseData2Desc, 
    caseData3Desc => $caseData3Desc, 
    caseTimestamp  => $casaTimestamp
  );
}

# Create new Club or Service
elsif ( $query->param('action') eq 'create' ) {
  my $casaId = $query->param('casaId');
  my $title = $query->param('title');
  my $description = $query->param('description');
  my $casData1 = $query->param('casData1');
  my $casData2 = $query->param('casData2');
  my $casData3 = $query->param('casData3');
  my $startDate = $query->param('startDate');
  my $endDate = $query->param('endDate');
                            
  my ( $createdSuccessfully, $errorCode, $errorMessage ) 
    = AddClubOrService( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $branchcode );
                              
  $template->param(
    previousActionCreate => 1,
    createdTitle => $title,
  );
                                          
  if ( $createdSuccessfully ) {
    $template->param( createSuccess => 1 );
  } else {
    $template->param( createFailure => 1 );
    $template->param( failureMessage => $errorMessage );
  }                                                        
}

## Delete a club or service
elsif ( $query->param('action') eq 'delete' ) {
  my $casId = $query->param('casId');
  my $success = DeleteClubOrService( $casId );
    
  $template->param( previousActionDelete => 1 );
  if ( $success ) {
    $template->param( deleteSuccess => 1 );
  } else {
    $template->param( deleteFailure => 1 );
  }
}

## Edit a club or service: grab data, put in form.
elsif ( $query->param('action') eq 'edit' ) {
  my $casId = $query->param('casId');
  my ( $casId, $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $timestamp ) = GetClubOrService( $casId );

  my ( $casaId, $casaType, $casaTitle, $casaDescription, $casaPublicEnrollment, 
       $casData1Title, $casData2Title, $casData3Title, 
       $caseData1Title, $caseData2Title, $caseData3Title, 
       $casData1Desc, $casData2Desc, $casData3Desc, 
       $caseData1Desc, $caseData2Desc, $caseData3Desc, 
       $casaTimestamp ) = GetClubOrServiceArchetype( $casaId );
       
  $template->param(
      previousActionSelectArchetype => 1,
      previousActionEdit => 1,
      editCasId => $casId,
      editCasaId => $casaId,
      editTitle => $title,
      editDescription => $description,
      editCasData1 => $casData1,
      editCasData2 => $casData2,
      editCasData3 => $casData3,
      editStartDate => $startDate,
      editEndDate => $endDate,
      editTimestamp => $timestamp,

      casaId => $casaId,
      casaTitle => $casaTitle,
      casData1Title => $casData1Title,
      casData2Title => $casData2Title,
      casData3Title => $casData3Title,
      casData1Desc => $casData1Desc,
      casData2Desc => $casData2Desc,
      casData3Desc => $casData3Desc      
  );
}

# Update a Club or Service
if ( $query->param('action') eq 'update' ) {
  my $casId = $query->param('casId');
  my $casaId = $query->param('casaId');
  my $title = $query->param('title');
  my $description = $query->param('description');
  my $casData1 = $query->param('casData1');
  my $casData2 = $query->param('casData2');
  my $casData3 = $query->param('casData3');
  my $startDate = $query->param('startDate');
  my $endDate = $query->param('endDate');
                            
  my ( $createdSuccessfully, $errorCode, $errorMessage ) 
    = UpdateClubOrService( $casId, $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate );
                              
  $template->param(
    previousActionUpdate => 1,
    updatedTitle => $title,
  );
                                          
  if ( $createdSuccessfully ) {
    $template->param( updateSuccess => 1 );
  } else {
    $template->param( updateFailure => 1 );
    $template->param( failureMessage => $errorMessage );
  }                                                        
}
                                                        
my $clubs = GetClubsAndServices( 'club', $query->cookie('branch') );
my $services = GetClubsAndServices( 'service', $query->cookie('branch') );
my $archetypes = GetClubsAndServicesArchetypes();

if ( $archetypes ) { ## Disable 'Create New Club or Service' if there are no archetypes defined.
	$template->param( archetypes => 1 );
}

$template->param(
		intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
		intranetstylesheet => C4::Context->preference("intranetstylesheet"),
		IntranetNav => C4::Context->preference("IntranetNav"),

		edit_clubs_services => 1,
		
		clubsLoop => $clubs,
		servicesLoop => $services,
		archetypesLoop => $archetypes,
		);

output_html_with_http_headers $query, $cookie, $template->output;
