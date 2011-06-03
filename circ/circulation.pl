#!/usr/bin/env perl

# written 8/5/2002 by Finlay
# script to execute issuing of books

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

use strict;
use warnings;
use CGI;
use C4::Output;
use C4::Print;
use C4::Auth qw/:DEFAULT get_session check_override_perms/;
use C4::Dates qw/format_date/;
use C4::Overdues qw( GetFinesSummary );
use List::Util qw( sum );
use C4::Branch; # GetBranches
use C4::Koha;   # GetPrinter
use C4::Circulation;
use C4::Items qw();
use C4::Members;
use C4::Accounts;
use C4::Biblio;
use C4::Reserves;
use C4::Context;
use C4::View::Member;
use CGI::Session;

use Date::Calc qw(
  Today
  Add_Delta_YM
  Add_Delta_Days
  Date_to_Days
);

sub FormatFinesSummary {
    my ( $borrower ) = @_;

    my %type_map = (
        L => 'lost_fines',
        F => 'overdue_fines',
        FU => 'overdue_fines',
        Res => 'reserve_fees'
    );

    my $dbh = C4::Context->dbh;
    my $summary = GetFinesSummary( $borrower->{'borrowernumber'} );
    my %params;
    foreach my $type ( keys %type_map ) {
        next if ( !$summary->{$type} );
        $params{$type_map{$type} . "_total"} = ( $params{ $type_map{$type} .  "_total" } || 0 ) 
        + $summary->{$type};
        delete $summary->{$type};
    }
    foreach my $type ( keys %$summary ) {
        next if ( $summary->{$type} > 0 );
        $params{"credits_total"} = ( $params{"credits_total"} || 0 ) - $summary->{$type};
        delete $summary->{$type};
    }

    # Since the types we care about have already been removed, all that is left is 'Other'
    $params{'other_fees_total'} = sum( values %$summary );
    delete($params{other_fees_total}) unless $params{other_fees_total};
    return +{ map { $_ => sprintf('%0.2f', $params{$_} || 0) } keys %params };
}

#
# PARAMETERS READING
#
my $query = new CGI;

my $dbh = C4::Context->dbh;

my $sessionID = $query->cookie("CGISESSID") ;
my $session = get_session($sessionID);

# branch and printer are now defined by the userenv
# but first we have to check if someone has tried to change them

my $branch = $query->param('branch');
if ($branch){
    # update our session so the userenv is updated
    $session->param('branch', $branch);
    $session->param('branchname', GetBranchName($branch));
}
my $dispreturn = C4::Context->preference('PatronDisplayReturn');
my $printer = $query->param('printer');
if ($printer){
    # update our session so the userenv is updated
    $session->param('branchprinter', $printer);
}

if (!C4::Context->userenv || !$branch) {
    if ($session->param('branch') eq 'NO_LIBRARY_SET') {
        # no branch set we can't issue
        print $query->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
        exit;
    }
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user (
    {
        template_name   => 'circ/circulation.tmpl',
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => '*' },
    }
);
my $branches = GetBranches();

my @failedrenews = $query->param('failedrenew');    # expected to be itemnumbers 
my %renew_failed;
for (@failedrenews) { $renew_failed{$_} = 1; }

my $findborrower = $query->param('findborrower');
if ($findborrower) {
    $findborrower =~ s|,| |g;
#$findborrower =~ s|'| |g;
}

$template->param(opentab_holds =>1) if $query->param('opentab_holds');
$template->param(from_searchtohold => 1, opentab_holds => 1) 
   if $query->param('from_searchtohold');
my $borrowernumber = $query->param('borrowernumber');

my $orderby = $query->param('orderby');

$branch  = C4::Context->userenv->{'branch'};  
$printer = C4::Context->userenv->{'branchprinter'};

if (C4::Context->preference("DisableHoldsIssueOverrideUnlessAuthorised") ) {
    $template->param( DisableHoldsIssueOverrideUnlessAuthorised => 1 );
}

# If Autolocated is not activated, we show the Circulation Parameters to chage settings of librarian
if (C4::Context->preference("AutoLocation") != 1) {
    $template->param(ManualLocation => 1);
}

if (C4::Context->preference("DisplayClearScreenButton")) {
    $template->param(DisplayClearScreenButton => 1);
}

my $barcode = $query->param('barcode') || '';
$barcode =~  s/^\s*|\s*$//g; # remove leading/trailing whitespace

$barcode = C4::Circulation::barcodedecode(barcode=>$barcode) if( $barcode && (C4::Context->preference('itemBarcodeInputFilter') || C4::Context->preference('itembarcodelength')));
my $stickyduedate  = $query->param('stickyduedate') || $session->param('stickyduedate');
my $duedatespec    = $query->param('duedatespec')   || $session->param('stickyduedate');
my $issueconfirmed = $query->param('issueconfirmed');
my $howReserve     = $query->param('howhandleReserve');
my $organisation   = $query->param('organisations');
my $print          = $query->param('print');
my $newexpiry      = $query->param('dateexpiry');

my $circ_session = {
    debt_confirmed => $query->param('debt_confirmed') // 0, # Don't show the debt error dialog twice
    charges_overridden => $query->param('charges_overridden') // 0,
    override_user => $query->param('override_user') // '',
    override_pass => $query->param('override_pass') // '',
};

if ( !override_can( $circ_session, 'override_max_fines' ) ) {
     $circ_session->{'charges_overridden'} = 0;
}

# Check if stickyduedate is turned off
if ( $barcode ) {
    # was stickyduedate loaded from session?
    if ( $stickyduedate && ! $query->param("stickyduedate") ) {
        $session->clear( 'stickyduedate' );
        $stickyduedate  = $query->param('stickyduedate');
        $duedatespec    = $query->param('duedatespec');
    }
}

if ($query->param('reserve_confirmed')) {
   my $perm = C4::Auth::haspermission(C4::Context->userenv->{id}, {superlibrarian => 1});
   if ($$perm{superlibrarian}) {
      $issueconfirmed = 1;   
   }
   elsif (C4::Context->preference('DisableHoldsIssueOverrideUnlessAuthorised')) {
      my $authcode = C4::Auth::checkpw( C4::Context->dbh, $query->param('auth_username'), $query->param('auth_password'), 0, my $bypass_userenv = 1 );
      $perm = C4::Auth::haspermission( $query->param('auth_username'), { 'superlibrarian' => 1 } );
      unless ( $authcode && $perm ) {
         $issueconfirmed = 0;
         $template->param(badauth=>1);
      }
   }
}
#set up cookie.....
# my $branchcookie;
# my $printercookie;
# if ($query->param('setcookies')) {
#     $branchcookie = $query->cookie(-name=>'branch', -value=>"$branch", -expires=>'+1y');
#     $printercookie = $query->cookie(-name=>'printer', -value=>"$printer", -expires=>'+1y');
# }
#

my ($datedueObj,$invalidduedate,$globalduedate);

if(C4::Context->preference('globalDueDate') && (C4::Context->preference('globalDueDate') =~ C4::Dates->regexp('syspref'))){
   $globalduedate = C4::Dates->new(C4::Context->preference('globalDueDate'));
}
my $duedatespec_allow = C4::Context->preference('SpecifyDueDate');
my $testduedate_allow = C4::Context->preference('AllowDueDateInPast');
if($duedatespec_allow){
    if ($duedatespec) {
        if ($duedatespec =~ C4::Dates->regexp('syspref')) {
            my $tempdate = C4::Dates->new($duedatespec);
            if ($tempdate and $tempdate->output('iso') gt C4::Dates->new()->output('iso')) {
                # i.e., it has to be later than today/now
                $datedueObj = $tempdate;
            } else {
                 if ($testduedate_allow) {
                     $datedueObj = $tempdate;
                 }
                 else {
                     $invalidduedate = 1;
                     $template->param(IMPOSSIBLE=>1, INVALID_DATE=>$duedatespec);
                 }
            }
        } else {
            $invalidduedate = 1;
            $template->param(IMPOSSIBLE=>1, INVALID_DATE=>$duedatespec);
        }
    } else {
        # pass global due date to tmpl if specifyduedate is true 
        # and we have no barcode (loading circ page but not checking out)
        if($globalduedate &&  ! $barcode ){
            $duedatespec = $globalduedate->output();
            $stickyduedate = 1;
        }
    }
} else {
    $datedueObj = $globalduedate if ($globalduedate);
}

my $todaysdate = C4::Dates->new->output('iso');

# check and see if we should print
my $inprocess;

if ( $barcode eq q{} ) {
    if ( $print && $print eq 'maybe' ) {
        $print = 'yes';
    }
    $inprocess = q{};

    my $charges = $query->param('charges');
    if (  $charges && $charges eq 'yes' ) {
        $template->param(
            PAYCHARGES     => 'yes',
            borrowernumber => $borrowernumber
        );
    }
} else {
    $inprocess = $query->param('inprocess');
}

if ( $print && $print eq 'yes' && $borrowernumber ne '' ) {
    printslip( $borrowernumber );
    $query->param( 'borrowernumber', '' );
    $borrowernumber = '';
}

#
# STEP 2 : FIND BORROWER
# if there is a list of find borrowers....
#
my $borrowerslist;
my $message;
if ($findborrower) {
    my ($count, $borrowers) = SearchMember( $findborrower, $orderby );
    my @borrowers = @$borrowers;
    if (C4::Context->preference("AddPatronLists")) {
        $template->param(
            "AddPatronLists_".C4::Context->preference("AddPatronLists")=> "1",
        );
        if (C4::Context->preference("AddPatronLists")=~/code/){
            my $categories = GetBorrowercategoryList;
            $categories->[0]->{'first'} = 1;
            $template->param(categories=>$categories);
        }
    }
    if ( $#borrowers == -1 ) {
        $query->param( 'findborrower', '' );
        $message = "'$findborrower'";
    }
    elsif ( $#borrowers == 0 ) {
        $query->param( 'borrowernumber', $borrowers[0]->{'borrowernumber'} );
        $query->param( 'barcode', '' );
        $borrowernumber = $borrowers[0]->{'borrowernumber'};
        $template->param( PreviousCardnumber => $borrowers[0]->{'PreviousCardnumber'} );
    }
    else {
        $borrowerslist = \@borrowers;
    }
}

# get the borrower information.....
my $borrower;
if ($borrowernumber) {
    if ($query->param('fromqueue')) {
        $template->param(
            queue_branchlimit => $query->param("queue_branchlimit"),
            queue_currPage    => $query->param('queue_currPage'),
            queue_limit       => $query->param('queue_limit'),
            queue_orderby     => $query->param('queue_orderby'),
            fromqueue         => 1,
            qbarcode          => $query->param("qbarcode")
        );
    }

    if ( C4::Context->preference('CheckoutTimeout') ) {
      $template->param( CheckoutTimeout => C4::Context->preference('CheckoutTimeout') );
    }

    $borrower = GetMemberDetails( $borrowernumber, 0, $circ_session );
    if ( $circ_session->{'override_user'} ) {
        $template->param( flagged => 1 );
    }
    
    ## Store data for last scanned borrower in cookies for future use.
    my $lbb = $query->cookie(-name=>'last_borrower_borrowernumber', -value=>"$borrowernumber", -expires=>'+1y');
    my $lbc = $query->cookie(-name=>'last_borrower_cardnumber', -value=>"$borrower->{'cardnumber'}", -expires=>'+1y');
    my $lbf = $query->cookie(-name=>'last_borrower_firstname', -value=>"$borrower->{'firstname'}", -expires=>'+1y');
    my $lbs = $query->cookie(-name=>'last_borrower_surname', -value=>"$borrower->{'surname'}", -expires=>'+1y');
    $cookie = [$cookie, $lbb, $lbc, $lbf, $lbs];        
    
    my ( $od, $issue, $fines ) = GetMemberIssuesAndFines( $borrowernumber );
    my $li = C4::Members::GetMemberLostItems(
      borrowernumber       => $borrowernumber,
      formatdate           => 1,
      only_claimsreturned  => 0,
    ) // [];
    my $numlostitems = scalar @$li;
    @$li = splice(@$li,0,5);
    $template->param( 
      lostitems    => $li,
      numlostitems => $numlostitems,
    );

    # Warningdate is the date that the warning starts appearing
    my (  $today_year,   $today_month,   $today_day) = Today();
    my ($warning_year, $warning_month, $warning_day) = split /-/, $borrower->{'dateexpiry'};
    my (  $enrol_year,   $enrol_month,   $enrol_day) = split /-/, $borrower->{'dateenrolled'};
    $warning_month = sprintf("%02d",$warning_month);
    # Renew day is calculated by adding the enrolment period to today
    my ( $renew_year, $renew_month, $renew_day );
    if ($enrol_year*$enrol_month*$enrol_day>0) {
        ( $renew_year, $renew_month, $renew_day ) =
        Add_Delta_YM( $enrol_year, $enrol_month, $enrol_day,
            0 , $borrower->{'enrolmentperiod'});
    }
    # if the expiry date is before today ie they have expired
    if ( $warning_year*$warning_month*$warning_day==0 
        || Date_to_Days($today_year,     $today_month, $today_day  ) 
         > Date_to_Days($warning_year, $warning_month, $warning_day) )
    {
        #borrowercard expired, no issues
        $template->param(
            flagged  => "1",
            noissues => "1",
            expired     => format_date($borrower->{dateexpiry}),
            renewaldate => format_date("$renew_year-$renew_month-$renew_day")
        );
    }
    # check for NotifyBorrowerDeparture
    elsif ( C4::Context->preference('NotifyBorrowerDeparture') &&
            Date_to_Days(Add_Delta_Days($warning_year,$warning_month,$warning_day,- C4::Context->preference('NotifyBorrowerDeparture'))) <
            Date_to_Days( $today_year, $today_month, $today_day ) ) 
    {
        # borrower card soon to expire warn librarian
        $template->param("warndeparture" => format_date($borrower->{dateexpiry}),
        flagged       => "1",);
        if (C4::Context->preference('ReturnBeforeExpiry')){
            $template->param("returnbeforeexpiry" => 1);
        }
    }
    # Check if patron is in debt collect
    $$borrower{last_reported_amount} ||= 0;
    if ($borrower->{'last_reported_amount'} > 0) {
      $template->param( debtcollect  => format_date($borrower->{'last_reported_date'}), flagged => 1);
    }
}

#
# STEP 3 : ISSUING
#
#

my %last_issue;

if ($barcode) {
  # always check for blockers on issuing
  my ( $error, $question ) =
    CanBookBeIssued( $borrower, $barcode, $datedueObj , $inprocess );
  my $blocker = $invalidduedate ? 1 : 0;
  if ($circ_session->{'debt_confirmed'} || $circ_session->{'charges_overridden'}) {
    delete $question->{'DEBT'};
    delete $error->{'DEBT'};
  }
  if (C4::Context->preference('GranularPermissions')){
     granular_overrides($template, $error, $question);
  }

  foreach my $impossible ( keys %$error ) {
            $template->param(
                $impossible => $$error{$impossible},
                IMPOSSIBLE  => 1
            );
            $blocker = 1;
        }

    if( !$blocker ){
        my $confirm_required = 0;
    	  unless($issueconfirmed) {
            #  Get the item title for more information
            my $getmessageiteminfo  = GetBiblioFromItemNumber(undef,$barcode);
		      $template->param( itemhomebranch => $getmessageiteminfo->{'homebranch'} );
		      
            # pass needsconfirmation to template if issuing is possible and user hasn't yet confirmed.
       	   foreach my $needsconfirmation ( keys %$question ) {
                 ## PTFS PT 7310367 don't display confirmation for holds
                 # next if $needsconfirmation eq 'RESERVED';
                 
                 ## PT 7310367 depracated, added syspref reservesNeedConfirmationOnCheckout
                 ## for work done on PT 9244211 holds should clear on checkout.
                 ## only skip confirmation for the syspref if borrower is the one who placed
                 ## a hold, either bib- or item-level.  This logic assumes the converse,
                 ## catching the case of an item-level hold.
                 ## FIXME: outstanding question is for a bib-level hold and no other
                 ## item is available to fill the hold. -hQ
                 if (C4::Context->preference('reservesNeedConfirmationOnCheckout')) {
       	            $template->param(
       	               $needsconfirmation => $$question{$needsconfirmation},
       	               getTitleMessageIteminfo => $getmessageiteminfo->{'title'},
       	               NEEDSCONFIRMATION  => 1
       	            );
       	            $confirm_required = 1;
                  }
       	    }
		  }
        if ($confirm_required) {
            $template->param(howhandleReserve=>$howReserve || 'requeue');
        }
        else {
            $datedueObj = C4::Circulation::AddIssue( 
               borrower       => $borrower,
               barcode        => $barcode,
               datedueObj     => $datedueObj,
               howReserve     => $howReserve,
            );
            my $item = C4::Items::GetItem(undef, $barcode) // {};
            my $biblio = GetBiblioData($item->{biblionumber}) // {};
            $last_issue{title} = $biblio->{title};
            $last_issue{barcode} = $barcode;
            $last_issue{duedate} = $datedueObj->output();
            
            $inprocess = 1;
            if($globalduedate && ! $stickyduedate && $duedatespec_allow ){
                $duedatespec = $globalduedate->output();
                $stickyduedate = 1;
            }
        }
    }
    
    if ($query->param('fromqueue')) {
       $template->param(backtoqueue=>1);
    }
}

# reload the borrower info for the sake of reseting the flags.....
if ($borrowernumber) {
    $borrower = GetMemberDetails( $borrowernumber, 0, $circ_session );

    # Get waiting reserves
    if (my $waiting_loop = C4::View::Member::GetWaitingReservesLoop($borrowernumber)) {
        $template->param(itemswaiting => 1, reservloop => $waiting_loop );
    }
}

##################################################################################
# BUILD HTML
# show all reserves of this borrower, and the position of the reservation ....

my @values;
my %labels;
my $CGIselectborrower;
$template->param( showinitials => C4::Context->preference('DisplayInitials') );
$template->param( showothernames => C4::Context->preference('DisplayOtherNames') );
if ($borrowerslist) {
    foreach (
        sort {(lc $a->{'surname'} cmp lc $b->{'surname'} || lc $a->{'firstname'} cmp lc $b->{'firstname'})
        } @$borrowerslist
      )
    {
        no warnings qw(uninitialized);
        push @values, $_->{'borrowernumber'};
        if (C4::Context->preference('DisplayInitials')) {
          $labels{ $_->{'borrowernumber'} } =
"$_->{'surname'}, $_->{'firstname'} $_->{'initials'} ... ($_->{'cardnumber'} - $_->{'categorycode'}) ...  $_->{'address'} ";
        }
        else {
          $labels{ $_->{'borrowernumber'} } =
"$_->{'surname'}, $_->{'firstname'} ... ($_->{'cardnumber'} - $_->{'categorycode'}) ...  $_->{'address'} ";
        }
    }
    $CGIselectborrower = CGI::scrolling_list(
        -name     => 'borrowernumber',
        -class    => 'focus',
        -id       => 'borrowernumber',
        -values   => \@values,
        -labels   => \%labels,
	-onclick  => "window.location = '/cgi-bin/koha/circ/circulation.pl?borrowernumber=' + this.value;",
        -size     => 7,
        -tabindex => '',
        -multiple => 0
    );
    $template->param(
      CGIselectborrower => $CGIselectborrower,
    );
   output_html_with_http_headers $query, $cookie, $template->output;
   exit;

}

my $flags = $borrower->{'flags'};
my $allow_override_login = C4::Context->preference( 'AllowOverrideLogin' );
foreach my $flag ( sort keys %{$flags} ) {
    $template->param( flagged=> 1);
    $flags->{$flag}->{'message'} =~ s#\n#<br />#g;
    if ( $flags->{$flag}->{'noissues'} ) {
        $template->param(
            flagged  => 1,
            noissues => 'true',
        );
        if ( $flag eq 'GNA' ) {
            $template->param( gna => 'true' );
        }
        elsif ( $flag eq 'LOST' ) {
            $template->param( lost => 'true' );
        }
        elsif ( $flag eq 'DBARRED' ) {
            $template->param( dbarred => 'true' );
        }
        elsif ( $flag eq 'CHARGES' ) {
            $template->param(
                charges    => 'true',
                chargesmsg => $flags->{'CHARGES'}->{'message'},
                chargesamount => $flags->{'CHARGES'}->{'amount'},
                charges_is_blocker => 1
            );
            if ( override_can( $circ_session, 'override_max_fines' ) ) {
                $template->param( charges_override => 1 );
            }

            $template->param( FormatFinesSummary( $borrower ) ) if ( C4::Context->preference( 'CircFinesBreakdown' ) );
        }
        if ( $flag eq 'CREDITS' ) {
            $template->param(
                credits    => 'true',
                creditsmsg => $flags->{'CREDITS'}->{'message'}
            );
        }
    }
    else {
        if ( $flag eq 'CHARGES' ) {
            $template->param(
                charges    => 'true',
                flagged    => 1,
                chargesmsg => $flags->{'CHARGES'}->{'message'},
                chargesamount => $flags->{'CHARGES'}->{'amount'},
            );

            $template->param( FormatFinesSummary( $borrower ) ) if ( C4::Context->preference( 'CircFinesBreakdown' ) );
        }
        elsif ( $flag eq 'CREDITS' ) {
            $template->param(
                credits    => 'true',
                creditsmsg => $flags->{'CREDITS'}->{'message'}
            );

            $template->param( FormatFinesSummary( $borrower ) ) if ( C4::Context->preference( 'CircFinesBreakdown' ) );
        }
        elsif ( $flag eq 'ODUES' ) {
            $template->param(
                odues    => 'true',
                flagged  => 1,
                oduesmsg => $flags->{'ODUES'}->{'message'}
            );

            my $items = $flags->{$flag}->{'itemlist'};
# useless ???
#             {
#                 my @itemswaiting;
#                 foreach my $item (@$items) {
#                     my ($iteminformation) =
#                         getiteminformation( $item->{'itemnumber'}, 0 );
#                     push @itemswaiting, $iteminformation;
#                 }
#             }
            if ( ! $query->param('module') or $query->param('module') ne 'returns' ) {
                $template->param( nonreturns => 'true' );
            }
        }
        elsif ( $flag eq 'NOTES' ) {
            $template->param(
                notes    => 'true',
                flagged  => 1,
                notesmsg => $flags->{'NOTES'}->{'message'}
            );
        }
    }
}

my $amountold = $borrower->{flags}->{'CHARGES'}->{'message'} || 0;
$amountold =~ s/^.*\$//;    # remove upto the $, if any

my $total = C4::Accounts::MemberAllAccounts(
   borrowernumber => $borrowernumber,
   total_only     => 1
);

if ( $borrower->{'category_type'} ~~ 'C') {
    my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
    my $cnt = scalar(@$catcodes);
    $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
    $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}

my $CGIorganisations;
my $member_of_institution;
if ( C4::Context->preference("memberofinstitution") ) {
    my $organisations = get_institutions();
    my @orgs;
    my %org_labels;
    foreach my $organisation ( keys %$organisations ) {
        push @orgs, $organisation;
        $org_labels{$organisation} = $organisations->{$organisation}->{'surname'};
    }
    $member_of_institution = 1;
    $CGIorganisations      = CGI::popup_menu(
        -id     => 'organisations',
        -name   => 'organisations',
        -labels => \%org_labels,
        -values => \@orgs,
    );
}

my $lib_messages_loop = GetMessages( $borrowernumber, 'L', $branch );
if($lib_messages_loop){ $template->param(flagged => 1 ); }

my $bor_messages_loop = GetMessages( $borrowernumber, 'B', $branch );
if($bor_messages_loop){ $template->param(flagged => 1 ); }
$template->param(
    lib_messages_loop		=> $lib_messages_loop,
    bor_messages_loop		=> $bor_messages_loop,
    all_messages_del		=> C4::Context->preference('AllowAllMessageDeletion'),
    findborrower                => $findborrower,
    borrower                    => $borrower,
    borrowernumber              => $borrowernumber,
    dispreturn                  => $dispreturn,
    branch                      => $branch,
    branchname                  => GetBranchName($borrower->{'branchcode'}),
    printer                     => $printer,
    printername                 => $printer,
    firstname                   => $borrower->{'firstname'},
    surname                     => $borrower->{'surname'},
    initials                    => $borrower->{'initials'},
    othernames                  => $borrower->{'othernames'},
    dateexpiry        => format_date($newexpiry),
    expiry            => format_date($borrower->{'dateexpiry'}),
    categorycode      => $borrower->{'categorycode'},
    categoryname      => $borrower->{description},
    address           => $borrower->{'address'},
    address2          => $borrower->{'address2'},
    email             => $borrower->{'email'},
    emailpro          => $borrower->{'emailpro'},
    borrowernotes     => $borrower->{'borrowernotes'},
    city              => $borrower->{'city'},
    zipcode	          => $borrower->{'zipcode'},
    country	          => $borrower->{'country'},
    phone             => $borrower->{'phone'} || $borrower->{'mobile'},
    cardnumber        => $borrower->{'cardnumber'},
    amountold         => $amountold,
    barcode           => $barcode,
    stickyduedate     => $stickyduedate,
    duedatespec       => $duedatespec,
    message           => $message,
    totaldue          => sprintf("%.2f", $total // 0),
    inprocess         => $inprocess,
    memberofinstution => $member_of_institution,
    CGIorganisations  => $CGIorganisations,
	 is_child          => ($borrower->{'category_type'} ~~ 'C'),
    circview          => 1,
    soundon           => C4::Context->preference("SoundOn"),
);

# save stickyduedate to session
if ($stickyduedate) {
    $session->param( 'stickyduedate', $duedatespec );
}


my ($picture, $dberror) = GetPatronImage($borrower->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

# get authorised values with type of BOR_NOTES
my @canned_notes;
my $sth = $dbh->prepare('SELECT * FROM authorised_values WHERE category = "BOR_NOTES"');
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {
  push @canned_notes, $row;
}
if ( scalar( @canned_notes ) ) {
  $template->param( canned_bor_notes_loop => \@canned_notes );
}

$template->param(
    override_user             => $circ_session->{'override_user'},
    override_pass             => $circ_session->{'override_pass'},
    charges_overridden        => $circ_session->{'charges_overridden'},
    debt_confirmed            => $circ_session->{'debt_confirmed'},
    SpecifyDueDate            => $duedatespec_allow,
    CircAutocompl             => C4::Context->preference('CircAutocompl'),
    AllowRenewalLimitOverride => C4::Context->preference('AllowRenewalLimitOverride'),
    dateformat                => C4::Context->preference('dateformat'),
    show_override             => $borrowernumber && C4::Context->preference("AllowOverrideLogin") && !$circ_session->{'override_user'},
    DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
    AllowDueDateInPast        => C4::Context->preference('AllowDueDateInPast'),
    UseReceiptTemplates => C4::Context->preference("UseReceiptTemplates"),
    last_issue                => ($last_issue{barcode}) ? [ \%last_issue ] : undef,
);

# Pass off whether to display initials or not
$template->param( showinitials => C4::Context->preference('DisplayInitials') );
output_html_with_http_headers $query, $cookie, $template->output;


sub granular_overrides {
    my ($circ_session, $error, $question) = @_;
    if ($question->{TOO_MANY} ) {
        if (!override_can($circ_session,'override_checkout_max')) {
            $error->{TOO_MANY} = $question->{TOO_MANY};
            delete $question->{TOO_MANY};
        }
    }
    if ($question->{NOT_FOR_LOAN_FORCING} ) {
        if (!override_can($circ_session,'override_non_circ')) {
            $error->{NOT_FOR_LOAN} = $question->{NOT_FOR_LOAN_FORCING};
            delete $question->{NOT_FOR_LOAN_FORCING};
        }
    }
    if ($error->{NO_MORE_RENEWALS} ) {
        if (override_can($circ_session,'override_max_renewals')) {
            $question->{NO_MORE_RENEWALS_FORCING} = $error->{NO_MORE_RENEWALS};
            delete $error->{NO_MORE_RENEWALS};
        }
    }

    return;
}

sub override_can {
    my ( $circ_session, $subperm ) = @_;

    return check_override_perms(
        C4::Context->userenv->{id},
        $circ_session->{'override_user'},
        $circ_session->{'override_pass'},
        { circulate => $subperm }
    );
}
