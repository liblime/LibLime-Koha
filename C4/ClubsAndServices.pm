package C4::ClubsAndServices;

# $Id: ClubsAndServices.pm,v 0.1 2007/04/10 kylemhall 

# This package is intended for dealing with clubs and services
# and enrollments in such, such as summer reading clubs, and
# library newsletters 

# Copyright 2007 Kyle Hall
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
#
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

require Exporter;

use C4::Context;

use DBI;

use vars qw($VERSION @ISA @EXPORT);

# set the version for version checking
$VERSION = 0.01;

=head1 NAME

C4::ClubsAndServices - Functions for managing clubs and services

=head1 FUNCTIONS

=over 2

=cut

@ISA = qw( Exporter );
@EXPORT = qw( 
  AddClubOrServiceArchetype  
  UpdateClubOrServiceArchetype
  DeleteClubOrServiceArchetype
  
  AddClubOrService
  UpdateClubOrService
  DeleteClubOrService
  
  EnrollInClubOrService
  GetEnrollments
  GetClubsAndServices
  GetClubOrService
  GetClubsAndServicesArchetypes
  GetClubOrServiceArchetype
  DoesEnrollmentRequireData
  CancelClubOrServiceEnrollment
  GetEnrolledClubsAndServices
  GetPubliclyEnrollableClubsAndServices
  GetAllEnrollableClubsAndServices
  GetCasEnrollments

  ReserveForBestSellersClub
  
  getTodayMysqlDateFormat
);

## function AddClubOrServiceArchetype
## Creates a new archetype for a club or service
## An archetype is something after which other things a patterned,
## For example, you could create a 'Summer Reading Club' club archtype
## which is then used to create an individual 'Summer Reading Club' 
## *for each library* in your system.
## Input:
##   $type : 'club' or 'service', could be extended to add more types
##   $title: short description of the club or service
##   $description: long description of the club or service
##   $publicEnrollment: If true, any borrower should be able
##       to enroll in club or service from opac. If false,
##       Only a librarian should be able to enroll a borrower
##       in the club or service.
##   $casData1Title: explanation of what is stored in
##      clubsAndServices.casData1Title
##   $casData2Title: same but for casData2Title
##   $casData3Title: same but for casData3Title
##   $caseData1Title: explanation of what is stored in
##     clubsAndServicesEnrollment.data1
##   $caseData2Title: Same but for data2
##   $caseData3Title: Same but for data3
##   $casData1Desc: Long explanation of what is stored in
##      clubsAndServices.casData1Title
##   $casData2Desc: same but for casData2Title
##   $casData3Desc: same but for casData3Title
##   $caseData1Desc: Long explanation of what is stored in
##     clubsAndServicesEnrollment.data1
##   $caseData2Desc: Same but for data2
##   $caseData3Desc: Same but for data3
##   $caseRequireEmail: If 1, enrollment in clubs or services based on this archetype will require a valid e-mail address field in the borrower
##	record as specified in the syspref AutoEmailPrimaryAddress
##   $branchcode: The branchcode for the branch where this Archetype was created
## Output:
##   $success: 1 if all database operations were successful, 0 otherwise
##   $errorCode: Code for reason of failure, good for translating errors in templates
##   $errorMessage: English description of error
sub AddClubOrServiceArchetype {
  my ( $type, $title, $description, $publicEnrollment, 
       $casData1Title, $casData2Title, $casData3Title, 
       $caseData1Title, $caseData2Title, $caseData3Title, 
       $casData1Desc, $casData2Desc, $casData3Desc, 
       $caseData1Desc, $caseData2Desc, $caseData3Desc, 
       $caseRequireEmail, $branchcode ) = @_;

  ## Check for all neccessary parameters
  if ( ! $type ) {
    return ( 0, 1, "No Type Given" );
  } 
  if ( ! $title ) {
    return ( 0, 2, "No Title Given" );
  } 
  if ( ! $description ) {
    return ( 0, 3, "No Description Given" );
  } 

  my $success = 1;

  my $dbh = C4::Context->dbh;

  my $sth;
  $sth = $dbh->prepare("INSERT INTO clubsAndServicesArchetypes ( casaId, type, title, description, publicEnrollment, caseRequireEmail, branchcode, last_updated ) 
                        VALUES ( NULL, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)");
  $sth->execute( $type, $title, $description, $publicEnrollment, $caseRequireEmail, $branchcode ) or $success = 0;
  my $casaId = $dbh->{'mysql_insertid'};
  $sth->finish;

  if ( $casData1Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData1Title = ? WHERE casaId = ?");
    $sth->execute( $casData1Title, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $casData2Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData2Title = ? WHERE casaId = ?");
    $sth->execute( $casData2Title, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $casData3Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData3Title = ? WHERE casaId = ?");
    $sth->execute( $casData3Title, $casaId ) or $success = 0;
    $sth->finish;
  }

  
  if ( $caseData1Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData1Title = ? WHERE casaId = ?");
    $sth->execute( $caseData1Title, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $caseData2Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData2Title = ? WHERE casaId = ?");
    $sth->execute( $caseData2Title, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $caseData3Title ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData3Title = ? WHERE casaId = ?");
    $sth->execute( $caseData3Title, $casaId ) or $success = 0;
    $sth->finish;
  }

  if ( $casData1Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData1Desc = ? WHERE casaId = ?");
    $sth->execute( $casData1Desc, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $casData2Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData2Desc = ? WHERE casaId = ?");
    $sth->execute( $casData2Desc, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $casData3Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET casData3Desc = ? WHERE casaId = ?");
    $sth->execute( $casData3Desc, $casaId ) or $success = 0;
    $sth->finish;
  }
  
  if ( $caseData1Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData1Desc = ? WHERE casaId = ?");
    $sth->execute( $caseData1Desc, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $caseData2Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData2Desc = ? WHERE casaId = ?");
    $sth->execute( $caseData2Desc, $casaId ) or $success = 0;
    $sth->finish;
  }
  if ( $caseData3Desc ) {
    $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes SET caseData3Desc = ? WHERE casaId = ?");
    $sth->execute( $caseData3Desc, $casaId ) or $success = 0;
    $sth->finish;
  }

  my ( $errorCode, $errorMessage );
  if ( ! $success ) {
    $errorMessage = "Database Failure";
    $errorCode = 4;
  }
  
  return( $success, $errorCode, $errorMessage );
  
}

## function UpdateClubOrServiceArchetype
## Updates an archetype for a club or service
## Input:
##   $casaId: id of the archetype to be updated
##   $type : 'club' or 'service', could be extended to add more types
##   $title: short description of the club or service
##   $description: long description of the club or service
##   $publicEnrollment: If true, any borrower should be able
##       to enroll in club or service from opac. If false,
##       Only a librarian should be able to enroll a borrower
##       in the club or service.
##   $casData1Title: explanation of what is stored in
##      clubsAndServices.casData1Title
##   $casData2Title: same but for casData2Title
##   $casData3Title: same but for casData3Title
##   $caseData1Title: explanation of what is stored in
##     clubsAndServicesEnrollment.data1
##   $caseData2Title: Same but for data2
##   $caseData3Title: Same but for data3
##   $casData1Desc: Long explanation of what is stored in
##      clubsAndServices.casData1Title
##   $casData2Desc: same but for casData2Title
##   $casData3Desc: same but for casData3Title
##   $caseData1Desc: Long explanation of what is stored in
##     clubsAndServicesEnrollment.data1
##   $caseData2Desc: Same but for data2
##   $caseData3Desc: Same but for data3
##   $caseRequireEmail: If 1, enrollment in clubs or services based on this archetype will require a valid e-mail address field in the borrower
##	record as specified in the syspref AutoEmailPrimaryAddress
## Output:
##   $success: 1 if all database operations were successful, 0 otherwise
##   $errorCode: Code for reason of failure, good for translating errors in templates
##   $errorMessage: English description of error
sub UpdateClubOrServiceArchetype {
  my ( $casaId, $type, $title, $description, $publicEnrollment, 
       $casData1Title, $casData2Title, $casData3Title, 
       $caseData1Title, $caseData2Title, $caseData3Title,
       $casData1Desc, $casData2Desc, $casData3Desc, 
       $caseData1Desc, $caseData2Desc, $caseData3Desc,
       $caseRequireEmail,
     ) = @_;

  ## Check for all neccessary parameters
  if ( ! $casaId ) {
    return ( 0, 1, "No Id Given" );
  }
  if ( ! $type ) {
    return ( 0, 2, "No Type Given" );
  } 
  if ( ! $title ) {
    return ( 0, 3, "No Title Given" );
  } 
  if ( ! $description ) {
    return ( 0, 4, "No Description Given" );
  } 

  my $success = 1;

  my $dbh = C4::Context->dbh;

  my $sth;
  $sth = $dbh->prepare("UPDATE clubsAndServicesArchetypes 
                        SET 
                        type = ?, title = ?, description = ?, publicEnrollment = ?, 
                        casData1Title = ?, casData2Title = ?, casData3Title = ?,
                        caseData1Title = ?, caseData2Title = ?, caseData3Title = ?, 
                        casData1Desc = ?, casData2Desc = ?, casData3Desc = ?,
                        caseData1Desc = ?, caseData2Desc = ?, caseData3Desc = ?, caseRequireEmail = ?,
                        last_updated = NOW() WHERE casaId = ?");

  $sth->execute( $type, $title, $description, $publicEnrollment, 
                 $casData1Title, $casData2Title, $casData3Title, 
                 $caseData1Title, $caseData2Title, $caseData3Title, 
                 $casData1Desc, $casData2Desc, $casData3Desc, 
                 $caseData1Desc, $caseData2Desc, $caseData3Desc, 
                 $caseRequireEmail, $casaId ) 
      or return ( $success = 0, my $errorCode = 6, my $errorMessage = $sth->errstr() );
  $sth->finish;
  
  return $success;
  
}

## function DeleteClubOrServiceArchetype
## Deletes an Archetype of the given id
## and all Clubs or Services based on it,
## and all Enrollments based on those clubs
## or services.
## Input:
##   $casaId : id of the Archtype to be deleted
## Output:
##   $success : 1 on successful deletion, 0 otherwise
sub DeleteClubOrServiceArchetype {
  my ( $casaId ) = @_;

  ## Paramter check
  if ( ! $casaId ) {
    return 0;
  }
  
  my $success = 1;

  my $dbh = C4::Context->dbh;

  my $sth;

  $sth = $dbh->prepare("DELETE FROM clubsAndServicesEnrollments WHERE casaId = ?");
  $sth->execute( $casaId ) or $success = 0;
  $sth->finish;

  $sth = $dbh->prepare("DELETE FROM clubsAndServices WHERE casaId = ?");
  $sth->execute( $casaId ) or $success = 0;
  $sth->finish;

  $sth = $dbh->prepare("DELETE FROM clubsAndServicesArchetypes WHERE casaId = ?");
  $sth->execute( $casaId ) or $success = 0;
  $sth->finish;

  return 1;
}

## function AddClubOrService
## Creates a new club or service in the database
## Input:
##   $type: 'club' or 'service', other types may be added as necessary.
##   $title: Short description of the club or service
##   $description: Long description of the club or service
##   $casData1: The data described in case.casData1Title
##   $casData2: The data described in case.casData2Title
##   $casData3: The data described in case.casData3Title
##   $startDate: The date the club or service begins ( Optional: Defaults to TODAY() )
##   $endDate: The date the club or service ends ( Optional )
##   $branchcode: Branch that created this club or service ( Optional: NULL is system-wide )
## Output:
##   $success: 1 on successful add, 0 on failure
##   $errorCode: Code for reason of failure, good for translating errors in templates
##   $errorMessage: English description of error
sub AddClubOrService {
  my ( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $branchcode ) = @_;

  ## Check for all neccessary parameters
  if ( ! $casaId ) {
    return ( 0, 1, "No Archetype Given" );
  } 
  if ( ! $title ) {
    return ( 0, 2, "No Title Given" );
  } 
  if ( ! $description ) {
    return ( 0, 3, "No Description Given" );
  } 
  
  my $success = 1;

  if ( ! $startDate ) {
    $startDate = getTodayMysqlDateFormat();
  }
  
  my $dbh = C4::Context->dbh;

  my $sth;
  if ( $endDate ) {
    $sth = $dbh->prepare("INSERT INTO clubsAndServices ( casId, casaId, title, description, casData1, casData2, casData3, startDate, endDate, branchcode, last_updated ) 
                             VALUES ( NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)");
    $sth->execute( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $branchcode ) or $success = 0;
  } else {
    $sth = $dbh->prepare("INSERT INTO clubsAndServices ( casId, casaId, title, description, casData1, casData2, casData3, startDate, branchcode, last_updated ) 
                             VALUES ( NULL, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)");
    $sth->execute( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $branchcode ) or $success = 0;
  }
  $sth->finish;

  my ( $errorCode, $errorMessage );
  if ( ! $success ) {
    $errorMessage = "Database Failure";
    $errorCode = 5;
  }
  
  return( $success, $errorCode, $errorMessage );
}

## function UpdateClubOrService
## Updates club or service in the database
## Input:
##   $casId: id of the club or service to be updated
##   $type: 'club' or 'service', other types may be added as necessary.
##   $title: Short description of the club or service
##   $description: Long description of the club or service
##   $casData1: The data described in case.casData1Title
##   $casData2: The data described in case.casData2Title
##   $casData3: The data described in case.casData3Title
##   $startDate: The date the club or service begins ( Optional: Defaults to TODAY() )
##   $endDate: The date the club or service ends ( Optional )
## Output:
##   $success: 1 on successful add, 0 on failure
##   $errorCode: Code for reason of failure, good for translating errors in templates
##   $errorMessage: English description of error
sub UpdateClubOrService {
  my ( $casId, $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate ) = @_;

  ## Check for all neccessary parameters
  if ( ! $casId ) {
    return ( 0, 1, "No casId Given" );
  }
  if ( ! $casaId ) {
    return ( 0, 2, "No Archetype Given" );
  } 
  if ( ! $title ) {
    return ( 0, 3, "No Title Given" );
  } 
  if ( ! $description ) {
    return ( 0, 4, "No Description Given" );
  } 
  
  my $success = 1;

  if ( ! $startDate ) {
    $startDate = getTodayMysqlDateFormat();
  }
  
  my $dbh = C4::Context->dbh;

  my $sth;
  if ( $endDate ) {
    $sth = $dbh->prepare("UPDATE clubsAndServices SET casaId = ?, title = ?, description = ?, casData1 = ?, casData2 = ?, casData3 = ?, startDate = ?, endDate = ?, last_updated = NOW() WHERE casId = ?");
    $sth->execute( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $casId ) or return( my $success = 0, my $errorCode = 5, my $errorMessage = $sth->errstr() );
  } else {
    $sth = $dbh->prepare("UPDATE clubsAndServices SET casaId = ?, title = ?, description = ?, casData1 = ?, casData2 = ?, casData3 = ?, startDate = ?, last_updated = NOW() WHERE casId = ?");
    $sth->execute( $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $casId ) or return( my $success = 0, my $errorCode = 5, my $errorMessage = $sth->errstr() );
  }
  $sth->finish;

  my ( $errorCode, $errorMessage );
  if ( ! $success ) {
    $errorMessage = "Database Failure";
    $errorCode = 5;
  }
  
  return( $success, $errorCode, $errorMessage );
}

## function DeleteClubOrService
## Deletes a club or service of the given id
## and all enrollments based on it.
## Input:
##   $casId : id of the club or service to be deleted
## Output:
##   $success : 1 on successful deletion, 0 otherwise
sub DeleteClubOrService {
  my ( $casId ) = @_;

  if ( ! $casId ) {
    return 0;
  }
  
  my $success = 1;

  my $dbh = C4::Context->dbh;

  my $sth;
  $sth = $dbh->prepare("DELETE FROM clubsAndServicesEnrollments WHERE casId = ?");
  $sth->execute( $casId ) or $success = 0;
  $sth->finish;

  $sth = $dbh->prepare("DELETE FROM clubsAndServices WHERE casId = ?");
  $sth->execute( $casId ) or $success = 0;
  $sth->finish;
  
  return 1;
}

## function EnrollInClubOrService
## Enrolls a borrower in a given club or service
## Input:
##   $casId: The unique id of the club or service being enrolled in
##   $borrowerCardnumber: The card number of the enrolling borrower
##   $dateEnrolled: Date the enrollment begins ( Optional: Defauls to TODAY() )
##   $data1: The data described in ClubsAndServicesArchetypes.caseData1Title
##   $data2: The data described in ClubsAndServicesArchetypes.caseData2Title
##   $data3: The data described in ClubsAndServicesArchetypes.caseData3Title
##   $branchcode: The branch where this club or service enrollment is,
##   $borrowernumber: ( Optional: Alternative to using $borrowerCardnumber )
## Output:
##   $success: 1 on successful enrollment, 0 on failure
##   $errorCode: Code for reason of failure, good for translating errors in templates
##   $errorMessage: English description of error
sub EnrollInClubOrService {
  my ( $casaId, $casId, $borrowerCardnumber, $dateEnrolled, $data1, $data2, $data3, $branchcode, $borrowernumber ) = @_;

  ## Check for all neccessary parameters
  unless ( $casaId ) {
    return ( 0, 1, "No casaId Given" );
  }
  unless ( $casId ) {
    return ( 0, 2, "No casId Given" );
  } 
  unless ( ( $borrowerCardnumber || $borrowernumber ) ) {
    return ( 0, 3, "No Borrower Given" );
  } 
  
  my $member;
  if ( $borrowerCardnumber ) {
    $member = C4::Members::GetMember( $borrowerCardnumber, 'cardnumber' );
  } elsif ( $borrowernumber ) {
    $member = C4::Members::GetMember( $borrowernumber, 'borrowernumber' );
  } else {
    return ( 0, 3, "No Borrower Given" );
  }
  
  unless ( $member ) {
    return ( 0, 4, "No Matching Borrower Found" );
  }

  my $casa = GetClubOrServiceArchetype( $casaId, 1 );
  if ( $casa->{'caseRequireEmail'} ) {
    my $AutoEmailPrimaryAddress = C4::Context->preference('AutoEmailPrimaryAddress');    
    unless( $member->{ $AutoEmailPrimaryAddress } && ($member->{$AutoEmailPrimaryAddress} ne "") ) {
      return( 0, 4, "Email Address Required: No Valid Email Address In Borrower Record" );
    }
  }
  
  $borrowernumber = $member->{'borrowernumber'};
  
  if ( isEnrolled( $casId, $borrowernumber ) ) { return ( 0, 5, "Member is already enrolled!" ); }

  if ( ! $dateEnrolled ) {
    $dateEnrolled = getTodayMysqlDateFormat();
  }

  my $dbh = C4::Context->dbh;
  my $sth = $dbh->prepare("INSERT INTO clubsAndServicesEnrollments ( caseId, casaId, casId, borrowernumber, data1, data2, data3, dateEnrolled, dateCanceled, last_updated, branchcode)
                           VALUES ( NULL, ?, ?, ?, ?, ?, ?, ?, NULL, NOW(), ? )");
  $sth->execute( $casaId, $casId, $borrowernumber, $data1, $data2, $data3, $dateEnrolled, $branchcode ) or return( my $success = 0, my $errorCode = 4, my $errorMessage = $sth->errstr() );
  $sth->finish;
  
  return $success = 1;
}

## function GetEnrollments
## Returns information about the clubs and services
##   the given borrower is enrolled in.
## Input:
##   $borrowernumber: The borrowernumber of the borrower
## Output:
##   $results: Reference to an array of associated arrays
sub GetEnrollments {
  my ( $borrowernumber ) = @_;

  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare("SELECT * FROM clubsAndServices, clubsAndServicesEnrollments 
                           WHERE clubsAndServices.casId = clubsAndServicesEnrollments.casId
                           AND clubsAndServicesEnrollments.borrowernumber = ?");
  $sth->execute( $borrowernumber ) or return 0;
  
  my @results;
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }
  
  $sth->finish;
  
  return \@results;
}

## function GetCasEnrollments
## Returns information about the clubs and services borrowers that are enrolled
## Input:
##   $casId: The id of the club or service to look up enrollments for
## Output:
##   $results: Reference to an array of associated arrays
sub GetCasEnrollments {
  my ( $casId ) = @_;

  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare("SELECT * FROM clubsAndServicesEnrollments, borrowers
                           WHERE clubsAndServicesEnrollments.borrowernumber = borrowers.borrowernumber
                           AND clubsAndServicesEnrollments.casId = ? AND dateCanceled IS NULL
                           ORDER BY surname, firstname");
  $sth->execute( $casId ) or return 0;
  
  my @results;
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }
  
  $sth->finish;
  
  return \@results;
}

## function GetClubsAndServices
## Returns information about clubs and services
## Input:
##   $type: ( Optional: 'club' or 'service' )
##   $branchcode: ( Optional: Get clubs and services only created by this branch )
## Output:
##   $results: 
##     Reference to an array of associated arrays
sub GetClubsAndServices {
  my ( $type, $branchcode ) = @_;
warn "C4::ClubsAndServices::GetClubsAndServices( $type, $branchcode )";
  my $dbh = C4::Context->dbh;

  my ( $sth, @results );
  if ( $type && $branchcode ) {
    $sth = $dbh->prepare("SELECT clubsAndServices.casId, 
                                 clubsAndServices.casaId,
                                 clubsAndServices.title, 
                                 clubsAndServices.description, 
                                 clubsAndServices.casData1,
                                 clubsAndServices.casData2,
                                 clubsAndServices.casData3,
                                 clubsAndServices.startDate, 
                                 clubsAndServices.endDate,
                                 clubsAndServices.last_updated,
                                 clubsAndServices.branchcode
                          FROM clubsAndServices, clubsAndServicesArchetypes 
                          WHERE ( 
                            clubsAndServices.casaId = clubsAndServicesArchetypes.casaId 
                            AND clubsAndServices.branchcode = ?
                            AND clubsAndServicesArchetypes.type = ? 
                        )");
    $sth->execute( $branchcode, $type ) or return 0;
    
  } elsif ( $type ) {
    $sth = $dbh->prepare("SELECT clubsAndServices.casId, 
                                 clubsAndServices.casaId,
                                 clubsAndServices.title, 
                                 clubsAndServices.description, 
                                 clubsAndServices.casData1,
                                 clubsAndServices.casData2,
                                 clubsAndServices.casData3,
                                 clubsAndServices.startDate, 
                                 clubsAndServices.endDate,
                                 clubsAndServices.last_updated,
                                 clubsAndServices.branchcode
                          FROM clubsAndServices, clubsAndServicesArchetypes 
                          WHERE ( 
                            clubsAndServices.casaId = clubsAndServicesArchetypes.casaId 
                            AND clubsAndServicesArchetypes.type = ? 
                        )");
    $sth->execute( $type ) or return 0;
    
  } elsif ( $branchcode ) {
    $sth = $dbh->prepare("SELECT clubsAndServices.casId, 
                                 clubsAndServices.casaId,
                                 clubsAndServices.title, 
                                 clubsAndServices.description, 
                                 clubsAndServices.casData1,
                                 clubsAndServices.casData2,
                                 clubsAndServices.casData3,
                                 clubsAndServices.startDate, 
                                 clubsAndServices.endDate,
                                 clubsAndServices.last_updated,
                                 clubsAndServices.branchcode
                          FROM clubsAndServices, clubsAndServicesArchetypes 
                          WHERE ( 
                            clubsAndServices.casaId = clubsAndServicesArchetypes.casaId 
                            AND clubsAndServices.branchcode = ? 
                        )");
    $sth->execute( $branchcode ) or return 0;
    
  } else { ## Get all clubs and services
    $sth = $dbh->prepare("SELECT * FROM clubsAndServices");
    $sth->execute() or return 0;  
  }

  while ( my $row = $sth->fetchrow_hashref ) {
warn "Found result: " . $row->{'title'};
    push( @results , $row );
  }

  $sth->finish;
  
  return \@results;
  
}


## function GetClubOrService
## Returns information about a club or service
## Input:
##   $casId: Id of club or service to get
## Output:
##   $results: 
##     $casId, $casaId, $title, $description, $casData1, $casData2, $casData3, $startDate, $endDate, $last_updated, $branchcode
sub GetClubOrService {
  my ( $casId ) = @_;

  my $dbh = C4::Context->dbh;

  my ( $sth, @results );
  $sth = $dbh->prepare("SELECT * FROM clubsAndServices WHERE casId = ?");
  $sth->execute( $casId ) or return 0;
    
  my $row = $sth->fetchrow_hashref;
  
  $sth->finish;
  
  return (
      $$row{'casId'},
      $$row{'casaId'},
      $$row{'title'},
      $$row{'description'},
      $$row{'casData1'},
      $$row{'casData2'},
      $$row{'casData3'},
      $$row{'startDate'},
      $$row{'endDate'},
      $$row{'last_updated'},
      $$row{'branchcode'}
  );
    
}

## function GetClubsAndServicesArchetypes
## Returns information about clubs and services archetypes
## Input:
##   $type: 'club' or 'service' ( Optional: Defaults to all types )
##   $branchcode: Get clubs or services created by this branch ( Optional )
## Output:
##   $results: 
##     Otherwise: Reference to an array of associated arrays
##     Except: 0 on failure
sub GetClubsAndServicesArchetypes {
  my ( $type, $branchcode ) = @_;
  my $dbh = C4::Context->dbh;
  
  my $sth;
  if ( $type && $branchcode) {
    $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE type = ? AND branchcode = ?");
    $sth->execute( $type, $branchcode ) or return 0;
  } elsif ( $type ) {
    $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE type = ?");
    $sth->execute( $type ) or return 0;
  } elsif ( $branchcode ) {
    $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE branchcode = ?");
    $sth->execute( $branchcode ) or return 0;
  } else {
    $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes");
    $sth->execute() or return 0;  
  }
  
  my @results;
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }

  $sth->finish;
  
  return \@results;
}

## function GetClubOrServiceArchetype
## Returns information about a club or services archetype
## Input:
##   $casaId: Id of Archetype to get
##   $asHashref: Optional, if true, will return hashref instead of array
## Output:
##   $results: 
##     ( $casaId, $type, $title, $description, $publicEnrollment, 
##     $casData1Title, $casData2Title, $casData3Title,
##     $caseData1Title, $caseData2Title, $caseData3Title, 
##     $casData1Desc, $casData2Desc, $casData3Desc,
##     $caseData1Desc, $caseData2Desc, $caseData3Desc, 
##     $caseRequireEmail, $last_updated, $branchcode )
##     Except: 0 on failure
sub GetClubOrServiceArchetype {
  my ( $casaId, $asHashref ) = @_;
  
  my $dbh = C4::Context->dbh;
  
  my $sth;
  $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE casaId = ?");
  $sth->execute( $casaId ) or return 0;

  my $row = $sth->fetchrow_hashref;
  
  $sth->finish;
  
  if ( $asHashref ) { return $row; }

  return (
      $$row{'casaId'},
      $$row{'type'},
      $$row{'title'},
      $$row{'description'},
      $$row{'publicEnrollment'},
      $$row{'casData1Title'},
      $$row{'casData2Title'},
      $$row{'casData3Title'},
      $$row{'caseData1Title'},
      $$row{'caseData2Title'},
      $$row{'caseData3Title'},
      $$row{'casData1Desc'},
      $$row{'casData2Desc'},
      $$row{'casData3Desc'},
      $$row{'caseData1Desc'},
      $$row{'caseData2Desc'},
      $$row{'caseData3Desc'},
      $$row{'caseRequireEmail'},
      $$row{'last_updated'},
      $$row{'branchcode'}
  );
}

## function DoesEnrollmentRequireData
## Returns 1 if the given Archetype has
##   data fields that need to be filled in
##   at the time of enrollment.
## Input:
##   $casaId: Id of Archetype to get
## Output:
##   1: Enrollment will require extra data
##   0: Enrollment will not require extra data
sub DoesEnrollmentRequireData {
  my ( $casaId ) = @_;
  
  my $dbh = C4::Context->dbh;
  
  my $sth;
  $sth = $dbh->prepare("SELECT caseData1Title FROM clubsAndServicesArchetypes WHERE casaId = ?");
  $sth->execute( $casaId ) or return 0;

  my $row = $sth->fetchrow_hashref;
  
  $sth->finish;

  if ( $$row{'caseData1Title'} ) {
    return 1;
  } else {
    return 0;
  }
}


## function CancelClubOrServiceEnrollment
## Cancels the given enrollment in a club or service
## Input:
##   $caseId: The id of the enrollment to be canceled
## Output:
##   $success: 1 on successful cancelation, 0 otherwise
sub CancelClubOrServiceEnrollment {
  my ( $caseId ) = @_;
  
  my $success = 1;
  
  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare("UPDATE clubsAndServicesEnrollments SET dateCanceled = CURDATE(), last_updated = NOW() WHERE caseId = ?");
  $sth->execute( $caseId ) or $success = 0;
  $sth->finish;
  
  return $success;
}

## function GetEnrolledClubsAndServices
## Returns information about clubs and services
## the given borrower is enrolled in.
## Input:
##   $borrowernumber
## Output:
##   $results: 
##     Reference to an array of associated arrays
sub GetEnrolledClubsAndServices {
  my ( $borrowernumber ) = @_;
  my $dbh = C4::Context->dbh;

  my ( $sth, @results );
  $sth = $dbh->prepare("SELECT
                          clubsAndServicesEnrollments.caseId,
                          clubsAndServices.casId,
                          clubsAndServices.casaId,
                          clubsAndServices.title,
                          clubsAndServices.description,
                          clubsAndServices.branchcode,
                          clubsAndServicesArchetypes.type,
                          clubsAndServicesArchetypes.publicEnrollment
                        FROM clubsAndServices, clubsAndServicesArchetypes, clubsAndServicesEnrollments
                        WHERE ( 
                          clubsAndServices.casaId = clubsAndServicesArchetypes.casaId 
                          AND clubsAndServices.casId = clubsAndServicesEnrollments.casId
                          AND ( clubsAndServices.endDate >= CURRENT_DATE() OR clubsAndServices.endDate IS NULL )
                          AND clubsAndServicesEnrollments.dateCanceled IS NULL
                          AND clubsAndServicesEnrollments.borrowernumber = ?
                        )
                        ORDER BY type, title
                       ");
  $sth->execute( $borrowernumber ) or return 0;
    
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }

  $sth->finish;
  
  return \@results;
  
}

## function GetPubliclyEnrollableClubsAndServices
## Returns information about clubs and services
## the given borrower can enroll in.
## Input:
##   $borrowernumber
## Output:
##   $results: 
##     Reference to an array of associated arrays
sub GetPubliclyEnrollableClubsAndServices {
  my ( $borrowernumber ) = @_;

  my $dbh = C4::Context->dbh;

  my ( $sth, @results );
  $sth = $dbh->prepare("
SELECT 
DISTINCT ( clubsAndServices.casId ), 
         clubsAndServices.title,
         clubsAndServices.description,
         clubsAndServices.branchcode,
         clubsAndServicesArchetypes.type,
         clubsAndServices.casaId
FROM clubsAndServices, clubsAndServicesArchetypes
WHERE clubsAndServicesArchetypes.casaId = clubsAndServices.casaId
AND clubsAndServicesArchetypes.publicEnrollment =1
AND clubsAndServices.casId NOT
IN (
  SELECT clubsAndServices.casId
  FROM clubsAndServices, clubsAndServicesEnrollments
  WHERE clubsAndServicesEnrollments.casId = clubsAndServices.casId
  AND clubsAndServicesEnrollments.dateCanceled IS NULL
  AND clubsAndServicesEnrollments.borrowernumber = ?
)
 ORDER BY type, title");
  $sth->execute( $borrowernumber ) or return 0;
    
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }

  $sth->finish;
  
  return \@results;
  
}

## function GetAllEnrollableClubsAndServices
## Returns information about clubs and services
## the given borrower can enroll in.
## Input:
##   $borrowernumber
## Output:
##   $results: 
##     Reference to an array of associated arrays
sub GetAllEnrollableClubsAndServices {
  my ( $borrowernumber, $branchcode ) = @_;
  
  if ( $branchcode eq '' ) {
    $branchcode = '%';
  }

  my $dbh = C4::Context->dbh;

  my ( $sth, @results );
  $sth = $dbh->prepare("
SELECT 
DISTINCT ( clubsAndServices.casId ), 
         clubsAndServices.title,
         clubsAndServices.description,
         clubsAndServices.branchcode,
         clubsAndServicesArchetypes.type,
         clubsAndServices.casaId
FROM clubsAndServices, clubsAndServicesArchetypes
WHERE clubsAndServicesArchetypes.casaId = clubsAndServices.casaId
AND ( 
  DATE(clubsAndServices.endDate) >= CURDATE()
  OR
  clubsAndServices.endDate IS NULL
)
AND clubsAndServices.branchcode LIKE ?
AND clubsAndServices.casId NOT
IN (
  SELECT clubsAndServices.casId
  FROM clubsAndServices, clubsAndServicesEnrollments
  WHERE clubsAndServicesEnrollments.casId = clubsAndServices.casId
  AND clubsAndServicesEnrollments.dateCanceled IS NULL
  AND clubsAndServicesEnrollments.borrowernumber = ?
)
 ORDER BY type, title");
  $sth->execute( $branchcode, $borrowernumber ) or return 0;
    
  while ( my $row = $sth->fetchrow_hashref ) {
    push( @results , $row );
  }

  $sth->finish;
  
  return \@results;
  
}


sub getBorrowernumberByCardnumber {
  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
  $sth->execute( @_ ) or return( 0 );

  my $row = $sth->fetchrow_hashref;
    
  my $borrowernumber = $$row{'borrowernumber'};
  $sth->finish;

  return( $borrowernumber );  
}

sub isEnrolled {
  my ( $casId, $borrowernumber ) = @_;
  
  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare("SELECT COUNT(*) as isEnrolled FROM clubsAndServicesEnrollments WHERE casId = ? AND borrowernumber = ? AND dateCanceled IS NULL");
  $sth->execute( $casId, $borrowernumber ) or return( 0 );

  my $row = $sth->fetchrow_hashref;
    
  my $isEnrolled = $$row{'isEnrolled'};
  $sth->finish;

  return( $isEnrolled );  
}

sub getTodayMysqlDateFormat {
  my ($day,$month,$year) = (localtime)[3,4,5];
  my $today = sprintf("%04d-%02d-%02d", $year + 1900, $month + 1, $day);
  return $today;
}

## This should really be moved to a new module, C4::ClubsAndServices::BestSellersClub
sub ReserveForBestSellersClub {
  my ( $biblionumber ) = @_;

  unless( $biblionumber ) { return; }
  
  my $dbh = C4::Context->dbh;
  my $sth;
  my @clubs;

  ## Grab the bib for this biblionumber, we will need the author and title to find the relevent clubs
  my $biblio_data = C4::Biblio::GetBiblioData( $biblionumber );
  my $author = $biblio_data->{'author'};
  $author =~ s/\.$//;
  my $title = $biblio_data->{'title'};
  my $itemtype = $biblio_data->{'itemtype'};
  
  ## Find the casaId for the Bestsellers Club archetype
  $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE title LIKE '%Bestsellers Club%' ");
  $sth->execute();
  while (my $casa = $sth->fetchrow_hashref()){

     my $casaId = $casa->{'casaId'};

     unless( $casaId ) { return; }
    
     ## Find all the relevent bestsellers clubs
     ## casData1 is title, casData2 is author
     my $sth2 = $dbh->prepare("SELECT * FROM clubsAndServices WHERE casaId = ?");
     $sth2->execute( $casaId );
     while ( my $club = $sth2->fetchrow_hashref() ) {
         #warn "Author/casData2 : '$author'/ " . $club->{'casData2'} . "'";
         #warn "Title/casData1 : '$title'/" . $club->{'casData1'} . "'";

         ## If the author, title or both match, keep it.
         if ( ($club->{'casData1'} eq $title) || ($club->{'casData2'} eq $author) ) {
            push( @clubs, $club );
            #warn "casId" . $club->{'casId'};
         } elsif ( $club->{'casData1'} =~ m/%/ ) { # Title is using % as a wildcard
            my @substrings = split(/%/, $club->{'casData1'} );
            my $all_match = 1;
            foreach my $sub ( @substrings ) {
               unless( $title =~ m/\Q$sub/) {
                  $all_match = 0;
               }
            }
           if ( $all_match ) { push( @clubs, $club ); }
         } elsif ( $club->{'casData2'} =~ m/%/ ) { # Author is using % as a wildcard
            my @substrings = split(/%/, $club->{'casData2'} );
            my $all_match = 1;
            foreach my $sub ( @substrings ) {
               unless( $author =~ m/\Q$sub/) {
                  $all_match = 0;
               }
            }
      
            ## Make sure the bib is in the list of itemtypes to use
            my @itemtypes = split( / /, $club->{'casData3'} );
            my $found_itemtype_match = 0;
            if ( @itemtypes ) { ## If no itemtypes are listed, all itemtypes are valid, skip test.
               foreach my $it ( @itemtypes ) {
                  if ( $it eq $itemtype ) {
                     $found_itemtype_match = 1;
                     last; ## Short circuit for speed.
                  }
               }
               $all_match = 0 unless ( $found_itemtype_match ); 
            }
      
            if ( $all_match ) { push( @clubs, $club ); }
         }
     }
   }
  
  unless( scalar( @clubs ) ) { return; }
  
  ## Get all the members of the relevant clubs, but only get each borrower once, even if they are in multiple relevant clubs
  ## Randomize the order of the borrowers
  my @casIds;
  my $sql = "SELECT DISTINCT(borrowers.borrowernumber) FROM borrowers, clubsAndServicesEnrollments
             WHERE clubsAndServicesEnrollments.borrowernumber = borrowers.borrowernumber
             AND (";
  my $clubsCount = scalar( @clubs );
  foreach my $club ( @clubs ) {
    $sql .= " casId = ?";
    if ( --$clubsCount ) {
      $sql .= " OR";
    }
    push( @casIds, $club->{'casId'} );
  }
  $sql .= " ) ORDER BY RAND()";
  
  
  $sth = $dbh->prepare( $sql );
  $sth->execute( @casIds );
  my @borrowers;
  while ( my $borrower = $sth->fetchrow_hashref() ) {
    push( @borrowers, $borrower );
  }
  
  unless( scalar( @borrowers ) ) { return; }
  
  my $priority = 1;
  foreach my $borrower ( @borrowers ) {
    C4::Reserves::AddReserve(
      my $branch = $borrower->{'branchcode'},
      my $borrowernumber = $borrower->{'borrowernumber'},
      $biblionumber,
      my $constraint = 'a',
      my $bibitems,
      $priority,
      '',
      my $notes = "Automatic Reserve for Bestsellers Club",
      $title,
      my $checkitem,
      my $found,
      my $expire_date
    );
    $priority++;
  }
}

1;

__END__

=back

=head1 AUTHOR

Kyle Hall <kylemhall@gmail.com>

=cut
