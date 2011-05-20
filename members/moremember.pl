#!/usr/bin/env perl

# Copyright 2000-2002 Katipo Communications
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


=head1 moremember.pl

 script to do a borrower enquiry/bring up borrower details etc
 Displays all the details about a borrower
 written 20/12/99 by chris@katipo.co.nz
 last modified 21/1/2000 by chris@katipo.co.nz
 modified 31/1/2001 by chris@katipo.co.nz
   to not allow items on request to be renewed

 needs html removed and to use the C4::Output more, but its tricky

=cut

use strict;
use warnings;
use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::AttributeTypes;
use C4::Members::Lists;
use C4::Accounts;
use C4::Dates qw/format_date/;
use C4::Reserves;
use C4::Circulation;
use C4::Koha;
use C4::Letters;
use C4::Biblio;
use C4::Branch; # GetBranchName
use C4::Form::MessagingPreferences;
use C4::View::Member;

#use Smart::Comments;
use Data::Dumper;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}

my $dbh = C4::Context->dbh;

my $input = new CGI;
if (!$debug) {
    $debug = $input->param('debug') || 0;
}
my $print = $input->param('print') // '';
my $error = $input->param('error');

my $quickslip = 0;
my $template_name;

if    ($print eq "page") { $template_name = "members/moremember-print.tmpl";   }
elsif ($print eq "slip") { $template_name = "members/moremember-receipt.tmpl"; }
elsif ($print eq "qslip") { $template_name = "members/moremember-receipt.tmpl"; $quickslip = 1; }
else {                     $template_name = "members/moremember.tmpl";         }

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => $template_name,
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => '*' },
        debug           => 1,
    }
);
my $borrowernumber = $input->param('borrowernumber');

#start the page and read in includes
my $data           = GetMember( $borrowernumber ,'borrowernumber');
my $roaddetails    = GetRoadTypeDetails( $data->{'streettype'} );
my $reregistration = $input->param('reregistration');

if ( not defined $data ) {
    $template->param (unknowuser => 1);
	output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

# re-reregistration function to automatic calcul of date expiry
if ( $reregistration && $reregistration eq 'y' ) {
	$data->{'dateexpiry'} = ExtendMemberSubscriptionTo( $borrowernumber );
}

my $category_type = $data->{'category_type'};

### $category_type

# in template <TMPL_IF name="I"> => instutitional (A for Adult& C for children) 
$template->param( $data->{'categorycode'} => 1 ); 

$debug and printf STDERR "dates (enrolled,expiry,birthdate) raw: (%s, %s, %s)\n", map {$data->{$_}} qw(dateenrolled dateexpiry dateofbirth);
foreach (qw(dateenrolled dateexpiry dateofbirth)) {
		my $userdate = $data->{$_};
		unless ($userdate) {
			$debug and warn sprintf "Empty \$data{%12s}", $_;
			$data->{$_} = '';
			next;
		}
		$userdate = C4::Dates->new($userdate,'iso')->output('syspref');
		$data->{$_} = $userdate || '';
		$template->param( $_ => $userdate );
}
$data->{'IS_ADULT'} = ( $data->{'categorycode'} ne 'I' );

for (qw(debarred gonenoaddress lost borrowernotes exclude_from_collection)) {
	 $data->{$_} and $template->param(flagged => 1) and last;
}

$data->{'ethnicity'} = fixEthnicity( $data->{'ethnicity'} );
$data->{ 'sex_'. ($data->{sex} // '') .'_p' } = 1;

if ( $category_type eq 'C') {
	if ($data->{'guarantorid'} ne '0' ) {
    	my $data2 = GetMember( $data->{'guarantorid'} ,'borrowernumber');
    	foreach (qw(address city B_address B_city phone mobile zipcode country B_country)) {
    	    $data->{$_} = $data2->{$_};
    	}
   }
   my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
   my $cnt = scalar(@$catcodes);

   $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
   $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}


if ( $data->{'ethnicity'} || $data->{'ethnotes'} ) {
    $template->param( printethnicityline => 1 );
}
if ( $category_type eq 'A' ) {
    $template->param( isguarantee => 1 );

    my ( $count, $guarantees ) = GetGuarantees( $data->{'borrowernumber'} );
    my @guaranteedata;
    
    foreach(@$guarantees) {
       push @guaranteedata, {
          borrowernumber => $$_{borrowernumber},
          cardnumber     => $$_{cardnumber},
          name           => join(' ',$$_{firstname},$$_{surname}),
       };
    }
    $template->param( guaranteeloop => \@guaranteedata );
    ( $template->param( adultborrower => 1 ) ) if ( $category_type eq 'A' );
}
else {
    if ($data->{'guarantorid'}){
	    my ($guarantor) = GetMember( $data->{'guarantorid'},'borrowernumber');
		$template->param(guarantor => 1);
		foreach (qw(borrowernumber cardnumber firstname surname)) {        
			  $template->param("guarantor$_" => $guarantor->{$_});
        }
    }
	if ($category_type eq 'C'){
		$template->param('C' => 1);
	}
}

my %bor;
$bor{'borrowernumber'} = $borrowernumber;

# Converts the branchcode to the branch name
my $samebranch;
if ( C4::Context->preference("IndependantBranches") ) {
    my $userenv = C4::Context->userenv;
    unless ( $userenv->{flags} % 2 == 1 ) {
        $samebranch = ( $data->{'branchcode'} eq $userenv->{branch} );
    }
    $samebranch = 1 if ( $userenv->{flags} % 2 == 1 );
}else{
    $samebranch = 1;
}
my $branchdetail = GetBranchDetail( $data->{'branchcode'});
$data->{'branchname'} = $branchdetail->{branchname};
my $lib1 = &GetSortDetails( "Bsort1", $data->{'sort1'} );
my $lib2 = &GetSortDetails( "Bsort2", $data->{'sort2'} );
$template->param( lib1 => $lib1 ) if ($lib1);
$template->param( lib2 => $lib2 ) if ($lib2);


##################################################################################
# BUILD HTML
# show all reserves of this borrower, and the position of the reservation ....

my $patron_infobox = C4::View::Member::BuildFinesholdsissuesBox($borrowernumber, $input);
$template->param(%$patron_infobox);

# current alert subscriptions
my $alerts = getalert($borrowernumber);
foreach (@$alerts) {
    $_->{ $_->{type} } = 1;
    $_->{relatedto} = findrelatedto( $_->{type}, $_->{externalid} );
}

my $candeleteuser;
my $userenv = C4::Context->userenv;
if($userenv->{flags} % 2 == 1){
    $candeleteuser = 1;
}elsif ( C4::Context->preference("IndependantBranches") ) {
    $candeleteuser = ( $data->{'branchcode'} eq $userenv->{branch} );
}else{
    if( C4::Auth::getuserflags( $userenv->{flags},$userenv->{number})->{borrowers} ) {
        $candeleteuser = 1;
    }else{
        $candeleteuser = 0;
    }
}

# check to see if patron's image exists in the database
# basically this gives us a template var to condition the display of
# patronimage related interface on
my ($picture, $dberror) = GetPatronImage($data->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

my $branch=C4::Context->userenv->{'branch'};

$data->{worklibraries} //= [];
$$data{_worklibraries} = join(", ",@{$$data{worklibraries}});
$$data{_worklibraries} ||= '(none)';
$$data{_worklibraries}   = '(none, not staff)' if $$data{category_type} ne 'S';
$template->param($data);

$template->param( lost_summary => GetLostStats( $borrowernumber, 1 ) );

if (C4::Context->preference('ExtendedPatronAttributes')) {
    $template->param(ExtendedPatronAttributes => 1);
    $template->param(patron_attributes => C4::Members::Attributes::GetBorrowerAttributes($borrowernumber));
    my @types = C4::Members::AttributeTypes::GetAttributeTypes();
    if (scalar(@types) == 0) {
        $template->param(no_patron_attribute_types => 1);
    }
}

if (C4::Context->preference('EnhancedMessagingPreferences')) {
    C4::Form::MessagingPreferences::set_form_values({ borrowernumber => $borrowernumber }, $template);
    $template->param(messaging_form_inactive => 1);
    $template->param(SMSSendDriver => C4::Context->preference("SMSSendDriver"));
    $template->param(SMSnumber     => defined $data->{'smsalertnumber'} ? $data->{'smsalertnumber'} : $data->{'mobile'});
}

my @previousCardnumbers = C4::Stats::GetPreviousCardnumbers( $borrowernumber );

if ( @previousCardnumbers ) {
  $template->param(
    previousCardnumbersLoop => \@previousCardnumbers,
    previousCardnumbersCount => scalar( @previousCardnumbers )
  );
}

$template->param(
    detailview => 1,
    AllowRenewalLimitOverride => C4::Context->preference("AllowRenewalLimitOverride"),
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
    CANDELETEUSER    => $candeleteuser,
    roaddetails     => $roaddetails,
    borrowernumber  => $borrowernumber,
    categoryname    => $data->{'description'},
    dispreturn      => C4::Context->preference('PatronDisplayReturn'),
    reregistration  => $reregistration,
    branch          => $branch,
    error           => $error,
    $error          => 1,
    StaffMember     => ($category_type eq 'S'),
    is_child        => ($category_type eq 'C'),
    dateformat      => C4::Context->preference("dateformat"),
    "dateformat_" . (C4::Context->preference("dateformat") || '') => 1,
    samebranch     => $samebranch,
    quickslip		  => $quickslip,
    UseReceiptTemplates => C4::Context->preference("UseReceiptTemplates"),
);

$template->param("showinitials" => C4::Context->preference('DisplayInitials'));
$template->param("showothernames" => C4::Context->preference('DisplayOthernames'));

$template->param(
    ListsLoop => GetLists(),
    MemberListsLoop => GetListsForMember({ borrowernumber => $borrowernumber }),
);

output_html_with_http_headers $input, $cookie, $template->output;
