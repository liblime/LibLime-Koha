#!/usr/bin/env perl

# script to modify reserves/holds
#
# Copyright 2011 PTFS/LibLime
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
use DateTime::Format::Strptime;
use C4::Output;
use C4::Reserves;
use C4::Auth;

my $query = CGI->new();
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   
        template_name   => "about.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
        debug           => 1,
    }
);

my @rank=$query->param('rank_request');
my @reservenumber=$query->param('reservenumber');
my $biblionumber=$query->param('biblionumber');
my @borrower=$query->param('borrowernumber');
my @branch=$query->param('pickup');
my @itemnumber=$query->param('itemnumber');
my @suspend=$query->param('suspend');
my $multi_hold = $query->param('multi_hold');
my $biblionumbers = $query->param('biblionumbers');
my $count=@rank;

for (my $i=0;$i<$count;$i++){
   undef $itemnumber[$i] unless ($itemnumber[$i]//'') ne '';
   if ($rank[$i] eq 'del') {
      CancelReserve($reservenumber[$i]);
   }
   else {
      ModReserve($rank[$i],$biblionumber,$borrower[$i],$branch[$i],$itemnumber[$i],$reservenumber[$i]);
      if ($query->param('suspend_' . $reservenumber[$i])) {
         my $format = DateTime::Format::Strptime->new(pattern => C4::Dates->DHTMLcalendar());
         my $resumedate = $format->parse_datetime($query->param('resumedate_' . $reservenumber[$i] ));
         SuspendReserve( $reservenumber[$i], $resumedate );
      }
      else {
         ResumeReserve( $reservenumber[$i] );
      }
   }
}
my $from=$query->param('from');
$from ||= q{};
if ( $from eq 'borrower'){
    print $query->redirect("/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrower[0]");
} elsif ( $from eq 'circ'){
    print $query->redirect("/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrower[0]");
} else {
     my $url = "/cgi-bin/koha/reserve/placehold.pl?";
     if ($multi_hold) {
         $url .= "multi_hold=1&biblionumber=$biblionumber&biblionumbers=$biblionumbers";
     } else {
         $url .= "biblionumber=$biblionumber";
     }
     print $query->redirect($url);
}
