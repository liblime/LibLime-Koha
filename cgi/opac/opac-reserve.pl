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

use Koha;
use CGI;
use List::Util qw/first/;
use C4::Biblio;
use C4::Items;
use C4::Auth;    # checkauth, getborrowernumber.
use C4::Koha;
use C4::Circulation;
use C4::Reserves;
use C4::Output;
use C4::Dates qw/format_date/;
use C4::Context;
use C4::Members;
use C4::Branch; # GetBranches
use C4::Debug;

my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-reserve.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

sub get_out ($$$) {
	output_html_with_http_headers(shift,shift,shift); # $query, $cookie, $template->output;
	exit;
}

# get borrower information ....
my ( $borr ) = GetMemberDetails( $borrowernumber );
## get borrower's maxholds, holds_block_threshold (price), circ_block_threshold (price)
my $cat = C4::Members::GetCategoryInfo($$borr{categorycode});

if ( C4::Context->preference('singleBranchMode') ) {
  $template->param( branch => $borr->{'branchcode'} );
}

# get branches and itemtypes and otheritemstatus
my $branches = GetBranches();
my $itemTypes = GetItemTypes();
my $itemstatuses = GetOtherItemStatus();

# There are two ways of calling this script, with a single biblio num
# or multiple biblio nums.
my $biblionumbers = $query->param('biblionumbers');
my $reserveMode = $query->param('reserve_mode');
if ($reserveMode && ($reserveMode eq 'single')) {
    my $bib = $query->param('single_bib');
    $biblionumbers = "$bib/";
}
if (! $biblionumbers) {
    $biblionumbers = $query->param('biblionumber');
}

if ((! $biblionumbers) && (! $query->param('place_reserve'))) {
    $template->param(message=>1, no_biblionumber=>1);
    &get_out($query, $cookie, $template->output);
}

# Pass the numbers to the page so they can be fed back
# when the hold is confirmed. TODO: Not necessary?
$template->param( biblionumbers => $biblionumbers );

# Each biblio number is suffixed with '/', e.g. "1/2/3/"
my @biblionumbers;
if ($biblionumbers =~ /\s*\|\s*/) {
  my @biblionums = split /\s*\|\s*/, $biblionumbers;
  my %seen = ();
  foreach my $bibnum (@biblionums) {
    push (@biblionumbers, $bibnum) unless $seen{$bibnum}++;
  }
}
else {
  @biblionumbers = split /\//, $biblionumbers;
}
if (($#biblionumbers < 0) && (! $query->param('place_reserve'))) {
    # TODO: New message?
    $template->param(message=>1, no_biblionumber=>1);
    &get_out($query, $cookie, $template->output);
}

# pass the pickup branch along....
my $branch = $query->param('branch') || $borr->{branchcode} || '' ;
($branches->{$branch}) or $branch = "";     # Confirm branch is real
$template->param( branch => $branch );

# make branch selection options...
my $CGIbranchloop = GetBranchesLoop($branch);
$template->param( CGIbranch => $CGIbranchloop );

#
#
# Build hashes of the requested biblio(item)s and items.
#
#

# Hash of biblionumber to biblio/biblioitems record.
my %biblioDataHash;

# Hash of itemnumber to item info.
my %itemInfoHash;
foreach my $biblioNumber (@biblionumbers) {
    my $biblioData = GetBiblioData($biblioNumber);

    $biblioDataHash{$biblioNumber} = $biblioData;

    my @itemInfos = GetItemsInfo($biblioNumber);
    $biblioData->{itemInfos} = \@itemInfos;
    foreach my $itemInfo (@itemInfos) {
        $itemInfoHash{$itemInfo->{itemnumber}} = $itemInfo;
    }

    # Compute the priority rank.
    my ( $rank, $reserves ) = GetReservesFromBiblionumber($biblioNumber,1);
    $biblioData->{reservecount} = $rank;
    foreach my $res (@$reserves) {
        my $found = $res->{'found'};
        if ( $found && ($found eq 'W') ) {
            $rank--;
        }
    }
    $rank++;
    $biblioData->{rank} = $rank;
}

#
#
# If this is the second time through this script, it
# means we are carrying out the hold request, possibly
# with a specific item for each biblionumber.
#
#
if ( $query->param('place_reserve') ) {

    my $notes = $query->param('notes');

    # List is composed of alternating biblio/item/branch
    my $selectedItems = $query->param('selecteditems');

    if ($query->param('reserve_mode') eq 'single') {
        # This indicates non-JavaScript mode, so there was
        # only a single biblio number selected.
        my $bib = $query->param('single_bib');
        my $item = $query->param("checkitem_$bib");
        if ($item eq 'any') {
            $item = '';
        }
        my $branch = $query->param('branch');
        $selectedItems = "$bib/$item/$branch/";
    }
    
    my @selectedItems = split /\//, $selectedItems;

    # Make sure there is a biblionum/itemnum/branch triplet for each item.
    # The itemnum can be 'any', meaning next available.
    my $selectionCount = @selectedItems;
    if (($selectionCount == 0) || (($selectionCount % 3) != 0)) {
        $template->param(message=>1, bad_data=>1);
        &get_out($query, $cookie, $template->output);
    }

    while (@selectedItems) {
        my $biblioNum = shift(@selectedItems);
        my $itemNum   = shift(@selectedItems) || undef;
        my $branch    = shift(@selectedItems); # i.e., branch code, not name

        my $singleBranchMode = $template->param('singleBranchMode');
        if ($singleBranchMode) {
            $branch = $borr->{'branchcode'};
        }

        my $biblioData = $biblioDataHash{$biblioNum};
        
	    # Check for user supplied reserve date
	    my $startdate;
	    if (C4::Context->preference( 'AllowHoldDateInFuture' ) && C4::Context->preference( 'OPACAllowHoldDateInFuture' )) {
	        $startdate = $query->param("reserve_date_$biblioNum");
	    }
        # FIXME: we only check one setting here, so a very savvy user could sidestep hold policies.
        if(C4::Reserves::TestMaxHolds(biblionumber => $biblioNum, borrower => $borr)){
            AddReserve($branch, $borrowernumber, $biblioNum, undef, $startdate, $notes, $itemNum);            
        } else {
            warn "Attempt to sidestep hold policies via opac.  Borrower $borrowernumber";
        }
    }

    print $query->redirect("/cgi-bin/koha/opac-user.pl#opac-user-holds");
    exit;
}

#
#
# Here we check that the borrower can actually make reserves Stage 1.
#
#
my $noreserves = 0;
$template->param( noreserve => 1 ) unless $$cat{holds_block_threshold};
$borr->{amountoutstanding} //= 0;
$cat->{holds_block_threshold} //= 0;
if ( ($borr->{'amountoutstanding'}>0) 
  && ($borr->{'amountoutstanding'} > $$cat{holds_block_threshold})
  && ($$cat{holds_block_threshold} > 0) ) {
    my $amount = sprintf "\$%.02f", $borr->{'amountoutstanding'};
    $template->param( message => 1 );
    $noreserves = 1;
    $template->param( too_much_oweing => $amount );
}
## data sync issues: check flags instead of amoutoutstanding
elsif ($$cat{holds_block_threshold}>0) {
   my $amount_owed = $$borr{flags}{CHARGES}{amount} // 0.00;
   if ($amount_owed > $$cat{holds_block_threshold}) {
      ## get the symbol of the currency, usually before the money figure
      $$borr{flags}{CHARGES}{message} ||= 'Patron owes $0.00';
      my($sym) = $$borr{flags}{CHARGES}{message} =~ /patron owes (.)\d/i;
      $sym   ||= '$';
      $noreserves = 1;
      $template->param(
         message        => 1,
         too_much_owed  => "$sym$amount_owed",
      );
   }
}

if ( $borr->{gonenoaddress} && ($borr->{gonenoaddress} eq 1) ) {
    $noreserves = 1;
    $template->param(
                     message => 1,
                     GNA     => 1
                    );
}
if ( $borr->{lost} && ($borr->{lost} eq 1) ) {
    $noreserves = 1;
    $template->param(
                     message => 1,
                     lost    => 1
                    );
}
if ( $borr->{debarred} && ($borr->{debarred} eq 1) ) {
    $noreserves = 1;
    $template->param(
                     message  => 1,
                     debarred => 1
                    );
}

my $userenv = C4::Context->userenv; 
my @reserves = GetReservesFromBorrowernumber( $borrowernumber );
$template->param( RESERVES => \@reserves );



if ((@reserves + @biblionumbers > $$cat{maxholds}) && $$cat{maxholds}) {
   $template->param(message => 1);
   $noreserves = 1;
   $template->param( too_many_reserves => $$cat{maxholds});
}

if ( C4::Context->preference('MaxShelfHoldsPerDay') ) {
  foreach my $biblionumber (@biblionumbers) {
    if ( GetAvailableItemsCount( $biblionumber ) ) {
      my $reserves_today = GetReserveCount( $borrowernumber, my $today = 1, my $shelf_holds_only = 1 );
      if ( $reserves_today >= C4::Context->preference('MaxShelfHoldsPerDay') ) {
        $noreserves = 1;
        $template->param( message => 1 );
        $template->param( too_many_shelf_holds_per_day =>  C4::Context->preference('MaxShelfHoldsPerDay') );
      }
    }
  }
}

my $no_on_shelf_holds_in_library = 0;
my $inBranchcode = C4::Branch::GetBranchByIp();
if (   $inBranchcode && !$noreserves
    && C4::Context->preference('AllowOnShelfHolds')
    && !$branches->{$inBranchcode}{branchonshelfholds}
   )
{
    for ( @biblionumbers ) {
        my $on_local_shelf = scalar grep {$_ ~~ $inBranchcode}
            @{C4::Circulation::BiblioIsAvailableAt($_)};
        if ($on_local_shelf) {
                $noreserves = 1;
                $template->param( message => 1 );
                $template->param( no_on_shelf_holds_in_library => 1 );
                $no_on_shelf_holds_in_library = 1;
        }
        last if $noreserves;
    }
}

foreach my $res (@reserves) {
    foreach my $biblionumber (@biblionumbers) {
        if ( $res->{'biblionumber'} == $biblionumber && $res->{'borrowernumber'} == $borrowernumber) {
#            $template->param( message => 1 );
#            $noreserves = 1;
#            $template->param( already_reserved => 1 );
#           $biblioDataHash{$biblionumber}->{already_reserved} = 1;
             my $biblioData = $biblioDataHash{$biblionumber};
             foreach my $itemInfo (@{$biblioData->{itemInfos}}) {
               if (!CanHoldMultipleItems($itemInfo->{itype},'opac')) {
                 $biblioDataHash{$biblionumber}->{already_reserved} = 1;
               }
             }
        }
    }
}

#
#
# Build the template parameters that will show the info
# and items for each biblionumber.
#
#
my $notforloan_label_of = get_notforloan_label_of();  # FIXME: deprecated function call.

my $biblioLoop = [];
my $numBibsAvailable = 0;
my $itemdata_enumchron = 0;
my $numPolicyBlocked = 0;
my $itemLevelTypes = C4::Context->preference('item-level_itypes');
$template->param('item-level_itypes' => $itemLevelTypes);

my $holdcount_by_itemtype = (C4::Context->preference('UseGranularMaxHolds')) ? C4::Reserves::GetHoldCountByItemtype($borrowernumber) : {};

foreach my $biblioNum (@biblionumbers) {

    my $record = GetMarcBiblio($biblioNum);
    next unless $record;
    my $subtitle = C4::Biblio::get_koha_field_from_marc('bibliosubtitle', 'subtitle', $record, '');

    # Init the bib item with the choices for branch pickup
    my %biblioLoopIter = ( branchChoicesLoop => $CGIbranchloop );

    # Get relevant biblio data.
    my $biblioData = $biblioDataHash{$biblioNum};
    if (! $biblioData) {
        $template->param(message=>1, bad_biblionumber=>$biblioNum);
        &get_out($query, $cookie, $template->output);
    }

    $biblioLoopIter{biblionumber} = $biblioData->{biblionumber};
    $biblioLoopIter{title} = $biblioData->{title};
    $biblioLoopIter{subtitle} = $subtitle;
    $biblioLoopIter{author} = $biblioData->{author};
    $biblioLoopIter{rank} = $biblioData->{rank};
    $biblioLoopIter{reservecount} = $biblioData->{reservecount};
    $biblioLoopIter{already_reserved} = $biblioData->{already_reserved};

    if (!$itemLevelTypes && $biblioData->{itemtype}) {
        $biblioLoopIter{description} = $itemTypes->{$biblioData->{itemtype}}{description};
        $biblioLoopIter{imageurl} = getitemtypeimagesrc() . "/". $itemTypes->{$biblioData->{itemtype}}{imageurl};
    }
    
    my $overItypeLimit = 0;
    if ( C4::Context->preference('UseGranularMaxHolds') ) {
        ## Note that the first time the page loads, we only know bibnumbers as the user hasn't selected
        # item-level holds yet.  So these checks should really happen in the client, since the user could
        # select an itemtype that they are under the limit on.  However, with the upcoming opac rebuild,
        # that's not going to happen now.

        my $do_per_itemtype = sub {  my %o = @_; $holdcount_by_itemtype->{$o{itemtype}}++; };

        if( !C4::Reserves::TestMaxHolds( biblionumber=>$biblioNum, borrower=>$borr,
                                     holdcount=>$holdcount_by_itemtype,
                                     action_per_itemtype=>$do_per_itemtype ) ){
            $overItypeLimit = 1;
            $biblioLoopIter{too_many_by_itemtype} = 1;
        }
    }
                  


    foreach my $itemInfo (@{$biblioData->{itemInfos}}) {
        $debug and warn $itemInfo->{'notforloan'};

        # Get reserve fee.
        my $fee = GetReserveFee($borrowernumber, $itemInfo->{'biblionumber'}, 'a',
                                [$itemInfo->{'biblioitemnumber'}] );
        $itemInfo->{'reservefee'} = sprintf "%.02f", ($fee ? $fee : 0.0);
        
        if ($itemLevelTypes && $itemInfo->{itype}) {
            $itemInfo->{description} = $itemTypes->{$itemInfo->{itype}}{description};
            $itemInfo->{imageurl} = getitemtypeimagesrc() . "/". $itemTypes->{$itemInfo->{itype}}{imageurl};
        }
        
        if (!$itemInfo->{'notforloan'} && !($itemInfo->{'itemnotforloan'} > 0)) {
            $biblioLoopIter{forloan} = 1;
        }
    }

    $biblioLoopIter{itemtype} = $biblioData->{itemtype};
    $biblioLoopIter{itemTypeDescription} = $itemTypes->{$biblioData->{itemtype}//''}{description};

    $biblioLoopIter{itemLoop} = [];
    my $numCopiesAvailable = 0;
    foreach my $itemInfo (@{$biblioData->{itemInfos}}) {
        my $itemNum = $itemInfo->{itemnumber};
        my $itemLoopIter = {};

        $itemLoopIter->{itemnumber} = $itemNum;
        $itemLoopIter->{barcode} = $itemInfo->{barcode};
        $itemLoopIter->{homeBranchName} = $branches->{$itemInfo->{homebranch}}{branchname};
        $itemLoopIter->{callNumber} = $itemInfo->{itemcallnumber};
        $itemLoopIter->{enumchron} = $itemInfo->{enumchron};
        $itemLoopIter->{copynumber} = $itemInfo->{copynumber};
        $itemLoopIter->{enumchron} = $itemInfo->{enumchron};
        $itemLoopIter->{serialseq} = $itemInfo->{serialseq};
        $itemLoopIter->{publisheddate} = $itemInfo->{publisheddate};
        $itemLoopIter->{serialinfo} = $itemInfo->{enumchron} || $itemInfo->{serialseq} || $itemInfo->{publisheddate};
        if ($itemLevelTypes) {
            $itemLoopIter->{description} = $itemInfo->{description};
            $itemLoopIter->{imageurl} = $itemInfo->{imageurl};
        }

        # If the holdingbranch is different than the homebranch, we show the
        # holdingbranch of the document too.
        if ( $itemInfo->{homebranch} ne $itemInfo->{holdingbranch} ) {
            $itemLoopIter->{holdingBranchName} =
              $branches->{ $itemInfo->{holdingbranch} }{branchname};
        }

        # If the item is currently on loan, we display its return date and
        # change the background color.
        my $issues= GetItemIssue($itemNum);
        if ( $issues->{'date_due'} ) {
            $itemLoopIter->{dateDue} = format_date($issues->{'date_due'});
            $itemLoopIter->{backgroundcolor} = 'onloan';
        }

        # checking reserve
        my ($reservenumber, $reservedate,$reservedfor,$expectedAt) = GetReservesFromItemnumber($itemNum);
        my $ItemBorrowerReserveInfo = GetMemberDetails( $reservedfor, 0);
        if ( defined $reservedate ) {
            $itemLoopIter->{backgroundcolor} = 'reserved';
            $itemLoopIter->{reservedate}     = format_date($reservedate);
            $itemLoopIter->{ReservedForBorrowernumber} = $reservedfor;
            $itemLoopIter->{ReservedForSurname}        = $ItemBorrowerReserveInfo->{'surname'};
            $itemLoopIter->{ReservedForFirstname}      = $ItemBorrowerReserveInfo->{'firstname'};
            $itemLoopIter->{ExpectedAtLibrary}         = $expectedAt;
            $itemLoopIter->{ReservedForThisBorrower}   = ( $reservedfor eq $borrowernumber );
        }

        # Get additional reserve info not returned by GetReservesFromItemnumber
        my ($count,$reserves) = GetReservesFromBiblionumber($itemInfo->{'biblionumber'});
        foreach my $res (@$reserves) {
            no warnings qw(uninitialized);
            $itemLoopIter->{reserve_status} = $res->{found} if ((defined $res->{found}) && ($res->{itemnumber} eq $itemLoopIter->{itemnumber})); 
        }

        $itemLoopIter->{notforloan} = $itemInfo->{notforloan};
        $itemLoopIter->{itemnotforloan} = $itemInfo->{itemnotforloan};

        # Management of the notforloan document
        if ( $itemLoopIter->{notforloan} || $itemLoopIter->{itemnotforloan}) {
            $itemLoopIter->{backgroundcolor} = 'other';
            $itemLoopIter->{notforloanvalue} =
              $notforloan_label_of->{ $itemLoopIter->{notforloan} };
        }

        # Management of lost or long overdue items
        if ( $itemInfo->{itemlost} ) {

            # FIXME localized strings should never be in Perl code
            $itemLoopIter->{message} =
                $itemInfo->{itemlost} == 1 ? "(lost)"
              : $itemInfo->{itemlost} == 2 ? "(long overdue)"
              : "";
            $itemInfo->{backgroundcolor} = 'other';
        }

        # Examine items.otherstatus and determine if it can be held
        if ($itemInfo->{otherstatus}) {
          foreach my $istatus (@$itemstatuses) {
            if ($istatus->{statuscode} eq $itemInfo->{otherstatus}) {
              $itemInfo->{otherstatus_description} = $istatus->{description};
              $template->param(otherstatus_description => $itemInfo->{otherstatus_description});
              if (!$istatus->{holdsallowed}) {
                $itemInfo->{noresstatus} = 1;
                $itemLoopIter->{noresstatus} = 1;
              }
              last;
            }
          }
        }

        # Check of the transfered documents
        my ( $transfertwhen, $transfertfrom, $transfertto ) =
          GetTransfers($itemNum);
        if ( $transfertwhen && ($transfertwhen ne '') ) {
            $itemLoopIter->{transfertwhen} = format_date($transfertwhen);
            $itemLoopIter->{transfertfrom} =
              $branches->{$transfertfrom}{branchname};
            $itemLoopIter->{transfertto} = $branches->{$transfertto}{branchname};
            $itemLoopIter->{nocancel} = 1;
        }

        # If there is no loan, return and transfer, we show a checkbox.
        $itemLoopIter->{notforloan} = $itemLoopIter->{notforloan} || 0;

        my $branch = C4::Circulation::GetCircControlBranch(
            pickup_branch     => $userenv? $userenv->{branch} : $itemInfo->{homebranch},
            item_homebranch   => $itemInfo->{homebranch},
            item_holdingbranch=> $itemInfo->{holdingbranch},
            borrower_branch   => $borr->{branchcode}
        );
        my $issuingrule = GetIssuingRule( $borr->{'categorycode'}, $itemInfo->{'itype'}, $branch );

        my $policy_holdallowed = 1;
        if ( ($issuingrule->{'holdallowed'} // 0) == 0 ||
                ( $issuingrule->{'holdallowed'} == 1 && $borr->{'branchcode'} ne $itemInfo->{'homebranch'} ) ) {
            $policy_holdallowed = 0;
        }

        if (IsAvailableForItemLevelRequest($itemNum) and not $itemInfo->{noresstatus}) {
            if ($policy_holdallowed) {
                if ($no_on_shelf_holds_in_library && !BranchHasACopy($biblioData, $inBranchcode)
                        && (
                               (defined $itemLoopIter->{dateDue} && $inBranchcode eq $itemInfo->{holdingbranch})
                            || $inBranchcode ne $itemInfo->{holdingbranch}
                            || $itemLoopIter->{reserve_status} ~~ [qw(W T)]
                            || $itemInfo->{damaged}
                            || $itemLoopIter->{nocancel}
                        )
                )
                    {
                        $template->param( message => undef);  # FIXME:  This is not safe.  The message flag is for all messages.
                                                              # The fact that this particular block isn't in place should not clear all other blocks.
                        $template->param( no_on_shelf_holds_in_library => undef);
                        $itemLoopIter->{available} = 1;
                        $numCopiesAvailable++;
                    }
                elsif (!$no_on_shelf_holds_in_library) {
                    $itemLoopIter->{available} = 1;
                    $numCopiesAvailable++;
                }
            } else {
                $numPolicyBlocked++;
            }
            if ($biblioLoopIter{already_reserved} && !CanHoldMultipleItems($itemInfo->{itype},'opac')) {
                $itemLoopIter->{available} = undef;
                $numCopiesAvailable--;
            }
            if (CanHoldMultipleItems($itemInfo->{itype},'opac')) {
              $template->param( message => undef, hold_already_exists => undef );   # FIXME: CLEARING message flag is BAD.  This needs to be rewritten.
            }
        }

	   # FIXME: move this to a pm
        my $dbh = C4::Context->dbh;
        my $sth2 = $dbh->prepare("SELECT * FROM reserves WHERE borrowernumber=? AND itemnumber=? AND found='W'");
        $sth2->execute($itemLoopIter->{ReservedForBorrowernumber}, $itemNum);
        while (my $wait_hashref = $sth2->fetchrow_hashref) {
            $itemLoopIter->{waitingdate} = format_date($wait_hashref->{waitingdate});
        }
    	$itemLoopIter->{imageurl} = getitemtypeimagelocation( 'opac', $itemTypes->{ $itemInfo->{itype} }{imageurl} );
         
        # Show serial enumeration when needed
        if ($itemLoopIter->{enumchron}) {
            $itemdata_enumchron = 1;    
        }
        $template->param( itemdata_enumchron => $itemdata_enumchron );
        
        push @{$biblioLoopIter{itemLoop}}, $itemLoopIter;
    }

    if ($numCopiesAvailable > 0 && !$overItypeLimit) {
        $numBibsAvailable++;
        $biblioLoopIter{bib_available} = 1;
        $biblioLoopIter{holdable} = 1;
    }

    if (C4::Context->preference('OPACItemHolds')) {
      if (C4::Context->preference('OPACUseHoldType')) {
        my $holdtype = (defined($record->subfield('942','r'))) ?
          $record->subfield('942','r') :
          C4::Context->preference('DefaultOPACHoldType');
        if ($holdtype eq 'item') {
          $biblioLoopIter{item_level} = 1;
        }
        elsif ($holdtype eq 'title') {
          $biblioLoopIter{title_level} = 1;
        }
        else {
          $biblioLoopIter{itemtitle_level} = 1;
        }
      }
      else {
        $biblioLoopIter{itemtitle_level} = 1;
      }
    }

    push @$biblioLoop, \%biblioLoopIter;
}

if ( $numBibsAvailable == 0 && ! $template->param('hold_already_exists')) {
    $template->param( none_available => 1, num_policy_blocked => $numPolicyBlocked, message => 1 );
}

my $itemTableColspan = 5;
if (!$template->param('OPACItemHolds')) {
    $itemTableColspan--;
}
if ($template->param('singleBranchMode')) {
    $itemTableColspan--;
}
$template->param(itemtable_colspan => $itemTableColspan);

# display infos
$template->param(bibitemloop => $biblioLoop);

# can set reserve date in future
if (
    C4::Context->preference( 'AllowHoldDateInFuture' ) &&
    C4::Context->preference( 'OPACAllowHoldDateInFuture' )
    ) {
    $template->param(
	reserve_in_future         => 1,
	DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
	);
}

$template->param(message=>1, hold_already_exists=>1, none_available=>0)
    unless (grep {!defined $_->{already_reserved}} values %biblioDataHash);

output_html_with_http_headers $query, $cookie, $template->output;
exit;

sub BranchHasACopy {
    my ($record, $branchcode) = @_;

    return 0 if $record->{serial};

    return first {
           $_->{holdingbranch} ~~ $branchcode
        && ! $_->{damaged}
        && ! $_->{itemlost}
        && ! $_->{otherstatus}
        && ! C4::Circulation::GetTransfers($_->{itemnumber})
        && !(   $_->{active_reserve_count}
             && C4::Reserves::GetReservesFromItemnumber($_->{itemnumber}))
    } @{$record->{itemInfos}};
}
