#!/usr/bin/env perl

# Copyright 2000-2002 Katipo Communications
#           2006 SAN-OP
#           2007 BibLibre, Paul POULAIN
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

=head1 returns.pl

script to execute returns of books

=cut

use Koha;

use CGI;
use Carp;
use C4::Context;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Circulation;
use C4::Dates qw/format_date/;
use Date::Calc qw/Add_Delta_Days/;
use C4::Calendar;
use C4::Print;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::LostItems;
use C4::Members;
use C4::Branch; # GetBranches GetBranchName
use C4::Koha;   # FIXME : is it still useful ?
use C4::ReceiptTemplates;

my $query = CGI->new();
my $sessionID = $query->cookie("CGISESSID");
my $session = get_session($sessionID);

if (!C4::Context->userenv){
	if ($session->param('branch') eq 'NO_LIBRARY_SET'){
		# no branch set we can't return
		print $query->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
		exit;
	}
} 

#getting the template
my $tmpl = 'returns';
if ($query->param('checkinnote')) { $tmpl = 'checkinnote'; }
my ( $template, $librarian, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/$tmpl.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => '*' },
    }
);

if ($query->param('checkinnote')) {
   my $done;
   if ($query->param('op') eq 'save') {
      if ($query->param('keepnote')) {
         # do nothing
      }
      else {   # discard checkinnotes
         C4::Items::ModItem(
            {checkinnotes=>undef,},
            $query->param('biblionumber'),
            $query->param('itemnumber'),
         );
      }
      $done = 1;
   }
   else {   # get checkinnotes
      my $item  = C4::Items::GetItem($query->param('itemnumber'));
      my $notes = $$item{checkinnotes};
      $notes    =~ s/\n/<br>/gs;
      $template->param('checkinnotes'=>$notes);
   }
   $template->param(
      done        => $done,
      biblionumber=> $query->param('biblionumber'),
      itemnumber  => $query->param('itemnumber'),
   );
   output_html_with_http_headers $query, $cookie, $template->output;
   exit;
}

#####################
#Global vars
my $branches = GetBranches();
my $printers = GetPrinters();

#my $branch  = C4::Context->userenv?C4::Context->userenv->{'branch'}:"";
my $printer = C4::Context->userenv ? C4::Context->userenv->{'branchprinter'} : '';
my $overduecharges = (C4::Context->preference('finesMode') && C4::Context->preference('finesMode') ne 'off');
my $HoldButtonConfirm = (C4::Context->preference('HoldButtonConfirm'));
my $HoldButtonIgnore = (C4::Context->preference('HoldButtonIgnore'));
my $HoldButtonPrintConfirm = (C4::Context->preference('HoldButtonPrintConfirm'));
my $userenv_branch = C4::Context->userenv->{'branch'} || '';

# Set up the item stack ....
my %returneditems;
my %riduedate;
my %rioverdue;
my %riborrowernumber;
my @inputloop;
foreach ( $query->param ) {
    (next) unless (/ri-(\d*)/);
    my %input;
    my $counter = $1;
    (next) if ( $counter > 20 );
    my $barcode        = $query->param("ri-$counter");
    my $duedate        = $query->param("dd-$counter");
    my $borrowernumber = $query->param("bn-$counter");
    my $overdue        = $query->param("od-$counter");
    $counter++;

    # decode barcode
    $barcode = barcodedecode(barcode=>$barcode) if(C4::Context->preference('itemBarcodeInputFilter') || C4::Context->preference('itembarcodelength'));

    ######################
    #Are these lines still useful ?
    $returneditems{$counter}    = $barcode;
    $riduedate{$counter}        = $duedate;
    $rioverdue{$counter}        = $overdue;
    $riborrowernumber{$counter} = $borrowernumber;

    #######################
    $input{counter}        = $counter;
    $input{barcode}        = $barcode;
    $input{duedate}        = $duedate;
    $input{borrowernumber} = $borrowernumber;
    $input{overdue}        = $overdue;
    push( @inputloop, \%input );
}

############
# Deal with the requests....
my $notransfer = 0;
my $reservenumber = $query->param('reservenumber');
if ($query->param('WT-itemNumber')){
   updateWrongTransfer ($query->param('WT-itemNumber'),$query->param('WT-waitingAt'),$query->param('WT-From'));
}
if ( $query->param('resbarcode') ) {
    my $item           = $query->param('itemnumber');
    my $borrowernumber = $query->param('borrowernumber');
    my $resbarcode     = $query->param('resbarcode');
    my $diffBranchReturned = $query->param('diffBranch');
    my $iteminfo   = GetBiblioFromItemNumber($item);
    # fix up item type for display
    $iteminfo->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $iteminfo->{'itype'} : $iteminfo->{'itemtype'};
    my $diffBranchSend = ($userenv_branch ne $diffBranchReturned) ? $diffBranchReturned : undef;

    ## wonky case of hold Waiting at branch B but here we are checkin at branch A,
    ## if we keep the item here, then we have to requeue the hold as a bib-level hold.  
    ## This case does not reflect reality and is a contrived scenario of playing with 
    ## Koha as superlibrarian
    if ($query->param('requeue')) {
        $notransfer = 1;
        ModReserve(1,
            $query->param('biblionumber'),
            $borrowernumber,
            $query->param('pickbranch'),
            undef,#$item,
            $reservenumber,
        );
        ModItem({holdingbranch=>$userenv_branch}, $iteminfo->{'biblionumber'}, $iteminfo->{'itemnumber'} );
#        C4::Items::ModItemTransfer($query->param('itemnumber')); # delete from branchtransfers
    }
    else {
# diffBranchSend tells ModReserveAffect whether document is expected in this library or not,
# i.e., whether to apply waiting status
        ModReserveAffect( $item, $borrowernumber, $diffBranchSend, $reservenumber );
    }

    if ($query->param('fromqueue')) {
       $template->param(
         closeGB     => 1,
         queue_branchlimit => $query->param('queue_branchlimit'),
         queue_currPage    => $query->param('queue_currPage'),
         queue_orderby     => $query->param('queue_orderby'),
         queue_limit       => $query->param('queue_limit'),
       );
    }
}

my $borrower;
my $returned = 0;
my $messages;
my $issueinformation;
my $itemnumber;
my $barcode     = $query->param('barcode') // '';
my $exemptfine  = $query->param('exemptfine');
my $dropboxmode = $query->param('dropboxmode');
my $dotransfer  = $query->param('dotransfer');
my $canceltransfer = $query->param('cancelTransfer');
my $checkin_override_date = $query->param('checkin_override_date');
my $calendar    = C4::Calendar->new( branchcode => $userenv_branch );
   #dropbox: get last open day (today - 1)
my $today       = C4::Dates->new();
my $today_iso   = $today->output('iso');
my $dropboxdate = $calendar->addDate($today, -1);
$barcode =~ s/^\s+|\s+$//g;

if ($ENV{HTTP_REFERER} =~ /$ENV{SCRIPT_NAME}/ && !$dotransfer && !$canceltransfer) {
   if ($dropboxmode) {
       $checkin_override_date = $dropboxdate->output();
   }
   $session->param('circ_ci_exemptfine', $exemptfine);
   $session->param('circ_ci_dropboxmode',$dropboxmode);
   $session->param('circ_ci_backdate',   $checkin_override_date);
}
else { # initial page load
   $exemptfine  = $session->param('circ_ci_exemptfine');
   $dropboxmode = $session->param('circ_ci_dropboxmode');
   $checkin_override_date = $session->param('circ_ci_backdate');
}

if ($dotransfer && ($notransfer==0)){
   # An item has been returned to a branch other than the homebranch, and the librarian has chosen to initiate a transfer
   my $transferitem = $query->param('transferitem');
   my $tobranch     = $query->param('tobranch');
   C4::Items::ModItemTransfer($transferitem, $userenv_branch, $tobranch, $userenv_branch);
}
elsif ($query->param('cancelTransfer')) {
   C4::Items::ModItemTransfer($query->param('itemnumber'));
}

if (C4::Context->preference('LinkLostItemsToPatron') 
&& $query->param('lost_item_id') 
&& $query->param('unlinkFromAccount')) {   
   ## bad legacy data: multiple lost entries for same item and patron, so this isn't going to work
   #C4::LostItems::DeleteLostItem($query->param('lost_item_id'));
   C4::LostItems::DeleteLostItemByItemnumber($query->param('itemnumber'));
}


# actually return book and prepare item table.....
if ($barcode) {
   ## this possibly expands a partial barcode using current active library prefix 
    $barcode = C4::Circulation::barcodedecode(barcode=>$barcode) 
    if(C4::Context->preference('itemBarcodeInputFilter') 
    || C4::Context->preference('itembarcodelength'));
    $itemnumber = C4::Items::GetItemnumberFromBarcode($barcode);
    if ( C4::Context->preference("InProcessingToShelvingCart") ) {
        my $item = C4::Items::GetItem( $itemnumber );
        if ( $item->{'location'} eq 'PROC' ) {
            croak 'Item has no permanent location defined' if (!$item->{permanent_location});
            $item->{'location'} = 'CART';
            C4::Items::ModItem( $item, $item->{'biblionumber'}, $item->{'itemnumber'} );
        }
    }

    if ( C4::Context->preference("ReturnToShelvingCart") ) {
        my $item = GetItem( $itemnumber );
        $item->{permanent_location} ||= $item->{location};
        $item->{location} = 'CART';
        C4::Items::ModItem( $item, $item->{'biblionumber'}, $item->{'itemnumber'} );
    }

#
# save the return
#

    if ($checkin_override_date ) {
       my $backdateObj = C4::Dates->new($checkin_override_date);
        ( $returned, $messages, $issueinformation, $borrower ) =
        C4::Circulation::AddReturn( $barcode, C4::Context->userenv->{'branch'}, $exemptfine, $dropboxmode, $backdateObj->output('iso'));
    } else {
        ( $returned, $messages, $issueinformation, $borrower ) =
        C4::Circulation::AddReturn( $barcode, C4::Context->userenv->{'branch'}, $exemptfine, $dropboxmode);
    }
    # get biblio description
    my $biblio = GetBiblioFromItemNumber($itemnumber);
    # fix up item type for display
    $biblio->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $biblio->{'itype'} : $biblio->{'itemtype'};

    $template->param(
        title            => $biblio->{'title'},
        homebranch       => $biblio->{'homebranch'},
        homebranchname   => $$branches{$$biblio{homebranch}}{branchname},
        author           => $biblio->{'author'},
        itembarcode      => $biblio->{'barcode'},
        itemtype         => $biblio->{'itemtype'},
        ccode            => $biblio->{'ccode'},
        itembiblionumber => $biblio->{'biblionumber'},    
    );
    my %input = (
        counter => 0,
        first   => 1,
        barcode => $barcode,
    );
    if ($returned) {
        my $duedate = $issueinformation->{'date_due'};
        $returneditems{0}      = $barcode;
        $riborrowernumber{0}   = $borrower->{'borrowernumber'};
        $riduedate{0}          = $duedate;
        $input{borrowernumber} = $borrower->{'borrowernumber'};
        $input{duedate}        = $duedate;
        $input{overdue}        = 1 if $issueinformation->{'overdue'};
        $rioverdue{0}          = $input{overdue};
        push( @inputloop, \%input );
    }
    elsif ( !$messages->{'BadBarcode'} && !$messages->{'ReturndateLtIssuedate'} ) {
        $input{duedate}   = 0;
        $returneditems{0} = $barcode;
        $riduedate{0}     = 0;
        if ( $messages->{'wthdrawn'} ) {
            $input{withdrawn}      = 1;
            $input{borrowernumber} = 'Item Cancelled';  # FIXME: should be in display layer ?
            $riborrowernumber{0}   = 'Item Cancelled';
        }
        else {
            $input{borrowernumber} = '&nbsp;';  # This seems clearly bogus.
            $riborrowernumber{0}   = '&nbsp;';
        }
        push( @inputloop, \%input );
    }
}
$template->param( inputloop => \@inputloop );

my $found    = 0;
my $waiting  = 0;
my $reserved = 0;
my $damaged  = 0;
my $damaged_othersavailable = 0;

# new op dev : we check if the document must be returned to its homebranch directly,
#  if the document is transfered, we have warning message.
if ( $messages->{'WasTransfered'} ) {
    $template->param(
        found          => 1,
        transfer       => 1,
        itemnumber     => $itemnumber,
        barcode        => $barcode,
    );
}

if ( $messages->{'NeedsTransfer'} ){
   $template->param(
      found          => 1,
      needstransfer  => 1,
      itemnumber     => $itemnumber,
   );
}

## deprecated: allow checkin in Circulation::AddReturn and manual transfer back
## to home branch.  Previously, this refused a return and caused an infinite
## loop in the event the item was loaned to a different branch for reasons other
## than checkout or holds
#if ( $messages->{'Wrongbranch'} ){
#   $template->param(
#      wrongbranch => 1,
#      rightbranch => $messages->{Wrongbranch}->{Rightbranch},
#   );
#}

# case of wrong transfert, if the document wasn't transfered to the right library (according to branchtransfer (tobranch) BDD)

if ( $messages->{'WrongTransfer'} and not $messages->{'WasTransfered'}) {
   $template->param(
        WrongTransfer  => 1,
        TransferWaitingAt => $messages->{'WrongTransfer'},
        WrongTransferItem => $messages->{'WrongTransferItem'},
        itemnumber => $itemnumber,
    );

    my $reserve    = $messages->{'ResFound'};
    my $branchname = $branches->{ $reserve->{'branchcode'} }->{'branchname'};
    my ($borr) = GetMemberDetails( $reserve->{'borrowernumber'}, 0 );
    my $name = $borr->{'surname'} . ", " . $borr->{'title'} . " " . $borr->{'firstname'};
    ## reroute for intransit reserve
    $template->param(
            TransferWaitingAtBranchname => $$branches{$$messages{WrongTransfer}}{branchname},
            TransferWaitingAtBranchcode => $$messages{WrongTransfer},
            wname           => $name,
            wborfirstname   => $borr->{'firstname'},
            wborsurname     => $borr->{'surname'},
            wbortitle       => $borr->{'title'},
            wborphone       => $borr->{'phone'},
            wboremail       => $borr->{'email'},
            wboraddress     => $borr->{'address'},
            wboraddress2    => $borr->{'address2'},
            wborcity        => $borr->{'city'},
            wborzip         => $borr->{'zipcode'},
            wborrowernumber => $reserve->{'borrowernumber'},
            wborcnum        => $borr->{'cardnumber'},
            wtransfertFrom  => $userenv_branch,
            wpickbranch     => $reserve->{branchcode},
            wpickbranchname => $$branches{$$reserve{branchcode}}{branchname},
            reroute         => ($$messages{WrongTransfer} eq $$reserve{branchcode})? 0:1,
    );
}

# Check to see if the item status has been changed to damaged.  If so, also
# check to see if other items are available for this bib record.

my $item = GetItem($itemnumber);
my @reserveinfo = GetReservesFromItemnumber($itemnumber);
if ($item->{damaged}) {
  $damaged = 1;
  if (!defined($reserveinfo[0])) { # Make sure there's no item specific hold
    my $biblio = GetBiblioFromItemNumber($itemnumber);
    my @itemsinfo = GetItemsInfo($biblio->{'biblionumber'});
    foreach my $iteminfo (@itemsinfo) {
      next if ($itemnumber eq $iteminfo->{itemnumber});
      if ((!defined($iteminfo->{onloan})) &&
          (!$iteminfo->{wthdrawn}) &&
          (!$iteminfo->{itemlost})) {
        $damaged = 0;
        $damaged_othersavailable = 1;
        last;
      }
    }
  }
}

#
# reserve found and item arrived at the expected branch
#
if ( $messages->{'ResFound'}) {
    my $reserve    = $messages->{'ResFound'};
    my $branchname = $branches->{ $reserve->{'branchcode'} }->{'branchname'};
    my ($borr) = GetMemberDetails( $reserve->{'borrowernumber'}, 0 );

    if ( $reserve->{'ResFound'} eq "Waiting" or $reserve->{'ResFound'} eq "Reserved" ) {
        if ($damaged) {
          $template->param(
                damaged      => 1
          );
        } elsif ($damaged_othersavailable) {
          $template->param(
                damaged_othersavailable => 1
          );
        } elsif ( $reserve->{'ResFound'} eq "Waiting" ) {
            $template->param(
                foundwait => ($reserve->{found} ~~ 'W')? 1:0,
                waiting   => ($userenv_branch eq $reserve->{'branchcode'})? 1:0,
                pull      => ($reserve->{found} ~~ 'T')                   ? 1:0,
            );
        } elsif ( $reserve->{'ResFound'} eq "Reserved" ) {
            $template->param(
                intransit    => ($userenv_branch eq $reserve->{'branchcode'} ? 0 : 1 ),
                transfertodo => ($userenv_branch eq $reserve->{'branchcode'} ? 0 : 1 ),
                resbarcode   => $barcode,
                reserved     => 1,
            );
        }

        # same params for Waiting or Reserved
        $template->param(
            found          => 1,
            currentbranch  => $branches->{$userenv_branch}->{'branchname'},
            destbranchname => $branches->{ $reserve->{'branchcode'} }->{'branchname'},
            destbranchcode => $branches->{ $reserve->{'branchcode'} }->{'branchcode'},
            name           => $borr->{'surname'} . ", " . $borr->{'title'} . " " . $borr->{'firstname'},
            borfirstname   => $borr->{'firstname'},
            borsurname     => $borr->{'surname'},
            bortitle       => $borr->{'title'},
            borphone       => $borr->{'phone'},
            boremail       => $borr->{'email'},
            boraddress     => $borr->{'address'},
            boraddress2    => $borr->{'address2'},
            borcity        => $borr->{'city'},
            borzip         => $borr->{'zipcode'},
            borcnum        => $borr->{'cardnumber'},
            debarred       => $borr->{'debarred'},
            gonenoaddress  => $borr->{'gonenoaddress'},
            barcode        => $barcode,
            reservenumber  => $reserve->{'reservenumber'},
            destbranch     => $reserve->{'branchcode'},
            borrowernumber => $reserve->{'borrowernumber'},
            itemnumber     => $reserve->{'itemnumber'},
            biblionumber   => $reserve->{'biblionumber'},
            reservenotes   => $reserve->{'reservenotes'},
            resWaiting     => ($reserve->{found} ~~ 'W')? 1:0,
        );
    } # else { ; }  # error?
}

# Error Messages
my @errmsgloop;
foreach my $code ( keys %$messages ) {
   my %err;
   my $exit_required_p = 0;
   if ( $code eq 'BadBarcode' ) {
        $err{badbarcode} = 1;
        $err{msg}        = $messages->{'BadBarcode'};
   }
   elsif ( $code eq 'NotIssued' ) {
        $err{notissued} = 1;
        if ($branches->{$messages->{IsPermanent}}) {
           $err{msg} = $branches->{ $messages->{'IsPermanent'} }->{'branchname'};
        }
   }
   elsif ( $code eq 'WasLost' ) {
      $err{waslost} = 1;
      $template->param(
         WasLost            => 1,
         itemnumber         => $$messages{$code}{itemnumber},
         lostborrowernumber => $$messages{$code}{lostborrowernumber},
         lost_item_id       => $$messages{$code}{lost_item_id},
      );
      if (C4::Context->preference('LinkLostItemsToPatron')) {
         my $lostbor = {};
         if ($$messages{$code}{lostborrowernumber}) {
            $lostbor = C4::Members::GetMember($$messages{$code}{lostborrowernumber});
         }
         $template->param(
            lostreturned       => 1,
            lostbor_surname    => $$lostbor{surname},
            lostbor_firstname  => $$lostbor{firstname},
            lostbor_cardnumber => $$lostbor{cardnumber},
         );
      }
   }
   elsif ( $code eq 'ResFound' ) {
      # $err{reserve} = 1;
      foreach(keys %{$$messages{$code}}) { $template->param("res_$_"=>$$messages{$code}{$_}) }
      $template->param(
         currBranch => $userenv_branch,
         pickbranchname => $$branches{$$messages{$code}{branchcode}}{branchname},
      );
   }
   elsif ( $code eq 'WasReturned' ) {
        ;    # FIXME... anything to do here?
   }
   elsif ( $code eq 'WasTransfered' ) {
        ;    # FIXME... anything to do here?
   }
   elsif ( $code eq 'wthdrawn' ) {
        $err{withdrawn} = 1;
        $exit_required_p = 1;
   }
   elsif ( ( $code eq 'IsPermanent' ) && ( not $messages->{'ResFound'} ) ) {
        if ( $messages->{'IsPermanent'} ne $userenv_branch ) {
            $err{ispermanent} = 1;
            $err{msg}         = $branches->{ $messages->{'IsPermanent'} }->{'branchname'};
        }
   }
   elsif ( $code eq 'WrongTransfer' ) {
        ;    # FIXME... anything to do here?
   }
   elsif ( $code eq 'WrongTransferItem' ) {
        ;    # FIXME... anything to do here?
   }
   elsif ( $code eq 'NeedsTransfer' ) {
   }
   elsif ( $code eq 'Wrongbranch' ) {
   }
   elsif ( $code eq 'ReturndateLtIssuedate' ) {
      $err{returndateLTissuedate} = 1;
      $err{msg} = sprintf("Return refused: Return date %s must be
            later than issue date %s",
            C4::Dates->new($$messages{$code},'iso')->output(),
            C4::Dates->new($$issueinformation{issuedate},'iso')->output()
        );
   }
      
   else {
        die "Unknown error code $code";    # note we need all the (empty) elsif's above, or we die.
        # This forces the issue of staying in sync w/ Circulation.pm
   }
   if (%err) {
        push( @errmsgloop, \%err );
   }
   last if $exit_required_p;
}
$template->param( errmsgloop => \@errmsgloop ) unless ((@errmsgloop==1) && $errmsgloop[0]{reserve});

# patrontable ....
if ($borrower) {
    my $flags = $borrower->{'flags'};
    my @flagloop;
    my $flagset;
    foreach my $flag ( sort keys %$flags ) {
        my %flaginfo;
        unless ($flagset) { $flagset = 1; }
        $flaginfo{redfont} = ( $flags->{$flag}->{'noissues'} );
        $flaginfo{flag}    = $flag;
        if ( $flag eq 'CHARGES' ) {
            $flaginfo{msg}            = $flag;
            $flaginfo{charges}        = 1;
            $flaginfo{chargeamount}   = $flags->{$flag}->{amount};
            $flaginfo{borrowernumber} = $borrower->{borrowernumber};
        }
        elsif ( $flag eq 'WAITING' ) {
            $flaginfo{msg}     = $flag;
            $flaginfo{waiting} = 1;
            my @waitingitemloop;
            my $items = $flags->{$flag}->{'itemlist'};
            foreach my $item (@$items) {
                my $biblio = GetBiblioFromItemNumber( $item->{'itemnumber'});
                push @waitingitemloop, {
                    biblionum => $biblio->{'biblionumber'},
                    barcode   => $biblio->{'barcode'},
                    title     => $biblio->{'title'},
                    brname    => $branches->{ $biblio->{'holdingbranch'} }->{'branchname'},
                };
            }
            $flaginfo{itemloop} = \@waitingitemloop;
        }
        elsif ( $flag eq 'ODUES' ) {
            my $items = $flags->{$flag}->{'itemlist'};
            my @itemloop;
            foreach my $item ( sort { $a->{'date_due'} cmp $b->{'date_due'} }
                @$items )
            {
                my $biblio = GetBiblioFromItemNumber( $item->{'itemnumber'});
                push @itemloop, {
                    duedate   => format_date($item->{'date_due'}),
                    biblionum => $biblio->{'biblionumber'},
                    barcode   => $biblio->{'barcode'},
                    title     => $biblio->{'title'},
                    brname    => $branches->{ $biblio->{'holdingbranch'} }->{'branchname'},
                };
            }
            $flaginfo{itemloop} = \@itemloop;
            $flaginfo{overdue}  = 1;
        }
        else {
            $flaginfo{other} = 1;
            $flaginfo{msg}   = $flags->{$flag}->{'message'};
        }
        push( @flagloop, \%flaginfo );
    }
    $template->param(
        flagset          => $flagset,
        flagloop         => \@flagloop,
        riborrowernumber => $borrower->{'borrowernumber'},
        riborcnum        => $borrower->{'cardnumber'},
        riborsurname     => $borrower->{'surname'},
        ribortitle       => $borrower->{'title'},
        riborfirstname   => $borrower->{'firstname'}
    );
}

#set up so only the last 8 returned items display (make for faster loading pages)
my $returned_counter = ( C4::Context->preference('numReturnedItemsToShow') ) ? C4::Context->preference('numReturnedItemsToShow') : 8;
my $count = 0;
my @riloop;
foreach ( sort { $a <=> $b } keys %returneditems ) {
    my %ri;
    if ( $count++ < $returned_counter ) {
        my $barcode = $returneditems{$_};
        my $duedate = $riduedate{$_};
        my $borrowerinfo;
        if ($duedate) {
            $ri{duedate}   = C4::Dates->new($duedate,'iso')->output();
            my ($borrower) = GetMemberDetails( $riborrowernumber{$_}, 0 );
            $ri{overdue}   = 1 if $rioverdue{$_};
            $ri{borrowernumber} = $borrower->{'borrowernumber'};
            $ri{borcnum}        = $borrower->{'cardnumber'};
            $ri{borfirstname}   = $borrower->{'firstname'};
            $ri{borsurname}     = $borrower->{'surname'};
            $ri{bortitle}       = $borrower->{'title'};
            $ri{bornote}        = $borrower->{'borrowernotes'};
            $ri{borcategorycode}= $borrower->{'categorycode'};
        }
        else {
            $ri{borrowernumber} = $riborrowernumber{$_};
        }

        #        my %ri;
        my $biblio = GetBiblioFromItemNumber(GetItemnumberFromBarcode($barcode));
        # fix up item type for display
        $biblio->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $biblio->{'itype'} : $biblio->{'itemtype'};
        $ri{itembiblionumber} = $biblio->{'biblionumber'};
        $ri{itemtitle}        = $biblio->{'title'};
        $ri{itemauthor}       = $biblio->{'author'};
        $ri{itemtype}         = $biblio->{'itemtype'};
        $ri{itemnote}         = $biblio->{'itemnotes'};
        $ri{havecheckinnotes} = $biblio->{'checkinnotes'} || undef;
        $ri{ccode}            = $biblio->{'ccode'};
        $ri{itemnumber}       = $biblio->{'itemnumber'};
        $ri{barcode}          = $barcode;
    }
    else {
        last;
    }
    push( @riloop, \%ri );
}

## umm... Perl bug w/ CGI and template param,
## pull variable out here or it'll insist queue_branchlimit='genbrname' literal
my $fromqueue         = $query->param('fromqueue');
my $queue_branchlimit = $query->param('queue_branchlimit');
my $queue_limit       = $query->param('queue_limit');
my $queue_currPage    = $query->param('queue_currPage');
my $queue_orderby     = $query->param('queue_orderby');
$template->param(
    riloop                  => \@riloop,
    HoldButtonConfirm       => $HoldButtonConfirm,
    HoldButtonIgnore        => $HoldButtonIgnore,
    HoldButtonPrintConfirm  => $HoldButtonPrintConfirm,
    fromqueue               => $fromqueue,
    queue_branchlimit       => $queue_branchlimit,
    queue_currPage          => $queue_currPage,
    queue_limit             => $queue_limit,
    queue_orderby           => $queue_orderby,
    genbrname               => $branches->{C4::Context->userenv->{'branch'}}->{'branchname'},
    genprname               => $printers->{$printer}->{'printername'},
    branchname              => $branches->{C4::Context->userenv->{'branch'}}->{'branchname'},
    printer                 => $printer,
    errmsgloop              => \@errmsgloop,
    exemptfine              => $exemptfine,
    dropboxmode             => $dropboxmode,
    checkin_override_date   => $dropboxmode? '' : $checkin_override_date,
    dropboxdate				 => $dropboxdate->output(),
  	 overduecharges           => $overduecharges,
    soundon                 => C4::Context->preference("SoundOn"),
    DHTMLcalendar_dateformat=> C4::Dates->DHTMLcalendar(),
    AllowCheckInDateChange  => C4::Context->preference('AllowCheckInDateChange'),
    UseReceiptTemplates     => C4::Context->preference("UseReceiptTemplates"),
    UseReceiptTemplates_NotFound            => GetAssignedReceiptTemplate({ action => 'not_found', branchcode => C4::Context->userenv->{'branch'} }),
    UseReceiptTemplates_HoldFound           => GetAssignedReceiptTemplate({ action => 'hold_found', branchcode => C4::Context->userenv->{'branch'} }),
    UseReceiptTemplates_TransitHold         => GetAssignedReceiptTemplate({ action => 'transit_hold', branchcode => C4::Context->userenv->{'branch'} }),
    UseReceiptTemplates_CheckIn             => GetAssignedReceiptTemplate({ action => 'check_in', branchcode => C4::Context->userenv->{'branch'} }),
    UseReceiptTemplates_ClaimsReturnedFound => GetAssignedReceiptTemplate({ action => 'claims_returned_found', branchcode => C4::Context->userenv->{'branch'} }),
);

# actually print the page!
output_html_with_http_headers $query, $cookie, $template->output;
exit;
__END__
