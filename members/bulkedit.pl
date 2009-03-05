#!/usr/bin/perl

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

# pragma
use strict;
use warnings;

# external modules
use CGI;
# use Digest::MD5 qw(md5_base64);

# internal modules
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::AttributeTypes;
use C4::Koha;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Input;
use C4::Log;
use C4::Letters;
use C4::Branch; # GetBranches

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}
	
my $input = new CGI;
($debug) or $debug = $input->param('debug') || 0;


my %data;

my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/bulkedit.tmpl",
           query => $input,
           type => "intranet",
           authnotrequired => 0,
           flagsrequired => {borrowers => 1},
           debug => ($debug) ? 1 : 0,
       });


# Pull borrowernumbers from cookie for bulk editing
my $borrower_list = $input->cookie("borrower_list");
my @borrowernumbers = split( /\//, $borrower_list );


if ( $input->param('update') ) { ## Update the borrowers
  my @fields = ( 'title', 'surname', 'firstname', 'dateofbirth', 'initials', 'othernames', 'sex',
                  'streetnumber', 'address', 'address2', 'city', 'zipcode', 'phone', 'phonepro', 'mobile',
                  'email', 'emailpro', 'fax', 'B_address', 'B_city', 'B_zipcode', 'B_phone', 'B_email',
                  'contactnote', 'altcontactfirstname', 'altcontactsurname', 'altcontactaddress1', 'altcontactaddress2',
                  'altcontactaddress3', 'altcontactzipcode', 'altcontactphone', 'branchcode', 'categorycode', 'sort1',
                  'sort2', 'dateenrolled', 'dateexpiry', 'opacnote', 'borrowernotes', 'gonenoaddress', 'debarred', 'lost'
                );
   
  foreach my $field ( @fields ) {
    if ( $input->param( "$field" ) ) { $data{ "$field" }  = $input->param( "$field" ); }
  }

  
  ## Radio buttons
  if ( $input->param( 'gonenoaddress' ) >= 0 ) {
    $data{'gonenoaddress'} = $input->param( 'gonenoaddress' ); 
  } else {
    delete $data{'gonenoaddress'};
  }
  if ( $input->param( 'debarred' ) >= 0 ) {
    $data{'debarred'} = $input->param( 'debarred' );
  } else {
    delete $data{'debarred'};
  }
  if ( $input->param( 'lost' ) >= 0 ) {
    $data{'lost'} = $input->param( 'lost' ); 
  } else {
    delete $data{'lost'};
  }

  if ( $data{'dateofbirth'} ) { $data{'dateofbirth'} =  format_date_in_iso( $data{'dateofbirth'} ); }
  if ( $data{'dateenrolled'} ) { $data{'dateenrolled'} =  format_date_in_iso( $data{'dateenrolled'} ); }
  if ( $data{'dateexpirty'} ) { $data{'dateexpiry'} =  format_date_in_iso( $data{'dateexpiry'} ); }
  
  $template->param("uppercasesurnames" => C4::Context->preference('uppercasesurnames'));

  my @modded_members;
  foreach my $borrowernumber ( @borrowernumbers ) {
    $data{ 'borrowernumber' } = $borrowernumber;
    my $success = ModMember( %data );
    
    my $member = GetMember( $borrowernumber, 'borrowernumber' );
    if ( $success ) { $member->{'updated'} = 1; }
    
    push( @modded_members, $member );
  }
  $template->param( edit_complete => 1 );
  $template->param( membersloop => \@modded_members );

} elsif ( $input->param('delete') ) { ## Delete the borrowers 
  my @modded_members;
  foreach my $borrowernumber ( @borrowernumbers ) {
    my $member = GetMember( $borrowernumber, 'borrowernumber' );

    DelMember( $borrowernumber ); ## Should use MoveMemberToDeleted() instead, but not working

    push( @modded_members, $member );
  }
  $template->param( delete_complete => 1 );
  $template->param( membersloop => \@modded_members );

} else { ## Build the edit form

# Get patron category codes
##Now all the data to modify a member.
my ($categories,$labels)=ethnicitycategories();
  
  my $ethnicitycategoriescount=$#{$categories};
  my $ethcatpopup;
  if ($ethnicitycategoriescount>=0) {
    $ethcatpopup = CGI::popup_menu(-name=>'ethnicity',
            -id => 'ethnicity',
            -tabindex=>'',
            -values=>$categories,
            -default=>$data{'ethnicity'},
            -labels=>$labels);
    $template->param(ethcatpopup => $ethcatpopup); # bad style, has to be fixed
  }
                                              

my @typeloop;
foreach (qw(C A S P I X)) {
    my $action="WHERE category_type=?";
	($categories,$labels)=GetborCatFromCatType($_,$action);
	my @categoryloop;
	foreach my $cat (@$categories){
		push @categoryloop,{'categorycode' => $cat,
			  'categoryname' => $labels->{$cat},
		};
	}
	my %typehash;
	$typehash{'typename'}=$_;
	$typehash{'categoryloop'}=\@categoryloop;
	push @typeloop,{'typename' => $_,
	  'categoryloop' => \@categoryloop};
}  
$template->param('typeloop' => \@typeloop);

# Get branches for library select
my @select_branch;
my %select_branches;

my $onlymine=(C4::Context->preference('IndependantBranches') && 
              C4::Context->userenv && 
              C4::Context->userenv->{flags} !=1  && 
              C4::Context->userenv->{branch}?1:0);
              
my $branches=GetBranches($onlymine);
my $default;

$branches->{''}->{branchname} = '';

for my $branch (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
    push @select_branch,$branch;
    $select_branches{$branch} = $branches->{$branch}->{'branchname'};
    $default = C4::Context->userenv->{'branch'} if (C4::Context->userenv && C4::Context->userenv->{'branch'});
}

my $CGIbranch = CGI::scrolling_list(-id    => 'branchcode',
            -name   => 'branchcode',
            -values => \@select_branch,
            -labels => \%select_branches,
            -size   => 1,
            -override => 1,  
            -multiple =>0,
            -default => $default,
            );


my $CGIorganisations;
my $member_of_institution;
if (C4::Context->preference("memberofinstitution")){
    my $organisations=get_institutions();
    my @orgs;
    my %org_labels;
    foreach my $organisation (keys %$organisations) {
        push @orgs,$organisation;
        $org_labels{$organisation}=$organisations->{$organisation}->{'surname'};
    }
    $member_of_institution=1;

    $CGIorganisations = CGI::scrolling_list( -id => 'organisations',
        -name     => 'organisations',
        -labels   => \%org_labels,
        -values   => \@orgs,
        -size     => 5,
        -multiple => 'true'

    );
}

if (C4::Context->preference('uppercasesurnames')) {
	$data{'surname'}    =uc($data{'surname'}    );
	$data{'contactname'}=uc($data{'contactname'});
}

foreach (qw(dateenrolled dateexpiry dateofbirth)) {
	$data{$_} = format_date($data{$_});	# back to syspref for display
	$template->param( $_ => $data{$_});
}

$template->param(%data);

$template->param(
  DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
);

$template->param(
  dateformat      => C4::Dates->new()->visual(),
  C4::Context->preference('dateformat') => 1,
  CGIbranch => $CGIbranch,
);

}

output_html_with_http_headers $input, $cookie, $template->output;
