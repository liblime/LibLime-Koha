#!/usr/bin/perl

#script to modify reserves/requests
#written 2/1/00 by chris@katipo.oc.nz
#last update 27/1/2000 by chris@katipo.co.nz


# Copyright 2000-2002 Katipo Communications
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
use warnings;

use CGI;
use C4::Output;
use C4::Reserves;
use C4::Auth;
my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   
        template_name   => "opac-account.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $biblionumber = $query->param('biblionumber');
my $suspend = $query->param('suspend');
my $resume = $query->param('resume');
my $reservenumber = $query->param('reservenumber');
my $resumedate = $query->param("resumedate_$reservenumber");
warn "Incoming ResumeDate: $resumedate";

if ( $resume && $reservenumber && $borrowernumber) {
	ResumeReserve( $reservenumber );
} elsif ( $suspend && $reservenumber && $borrowernumber) {
	if ( $resumedate ) {
		my @parts = split(/-/, $resumedate );
		$resumedate = $parts[2] . '-' . $parts[0] . '-' . $parts[1]; 
	}

	if ( $resumedate =~ m/(\d{4})-(0[13578]|1[02])-(0[1-9]|[12]\d|3[01])|(\d{4})-(0[469]|11])-(0[1-9]|[12]\d|30)|(\d{4})-(02)-(0[1-9]|1\d|2[0-9])/ ) {
            	SuspendReserve( $reservenumber, $resumedate );
        } else {              
        	SuspendReserve( $reservenumber );
        } 
} elsif ($reservenumber) {
	CancelReserve($reservenumber);
}
print $query->redirect("/cgi-bin/koha/opac-user.pl#opac-user-holds");
