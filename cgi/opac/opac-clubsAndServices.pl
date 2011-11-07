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
    = get_template_and_user({template_name => "opac-clubsAndServices.tmpl",
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

if ( $query->param('action') eq 'cancel' ) { ## Cancel the enrollment in the passed club or service
  CancelClubOrServiceEnrollment( $query->param('caseId') );
}

## Get the borrowers current clubs & services
my $enrolledClubsAndServices = GetEnrolledClubsAndServices( $borrowernumber );
$template->param( enrolledClubsAndServicesLoop => $enrolledClubsAndServices );

## Get clubs & services the borrower can enroll in from the OPAC
my $enrollableClubsAndServices = GetPubliclyEnrollableClubsAndServices( $borrowernumber );
$template->param( enrollableClubsAndServicesLoop => $enrollableClubsAndServices );

$template->param( clubs_services => 1 );

output_html_with_http_headers $query, $cookie, $template->output;
