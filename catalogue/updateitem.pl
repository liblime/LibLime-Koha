#!/usr/bin/env perl

# $Id: updateitem.pl,v 1.9.2.1.2.4 2006/10/05 18:36:50 kados Exp $
# Copyright 2006 LibLime
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
use C4::Auth;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Circulation;
use C4::Accounts;
use C4::Reserves;
use C4::LostItems;
use C4::Members;

my $cgi= new CGI;

my ($loggedinuser, $cookie, $sessionID) = checkauth($cgi, 0, {circulate => '*'}, 'intranet');

my $biblionumber=$cgi->param('biblionumber');
my $itemnumber=$cgi->param('itemnumber');
my $biblioitemnumber=$cgi->param('biblioitemnumber');
my $itemlost=$cgi->param('itemlost');
my $itemnotes=$cgi->param('itemnotes');
my $wthdrawn=$cgi->param('wthdrawn');
my $damaged=$cgi->param('damaged');
my $otherstatus=$cgi->param('otherstatus');
my $suppress=$cgi->param('suppress');

my $confirm=$cgi->param('confirm');
my $dbh = C4::Context->dbh;

# get the rest of this item's information
my $item_data_hashref = GetItem($itemnumber, undef);

# make sure item statuses are set to 0 if empty or NULL
for ($damaged,$itemlost,$wthdrawn,$suppress) {
    if (!$_ or $_ eq "") {
        $_ = 0;
    }
}

# modify MARC item if input differs from items table.
my $item_changes = {};
my $cancel_reserves = 0;
if (defined $itemnotes) { # i.e., itemnotes parameter passed from form
    if ((not defined $item_data_hashref->{'itemnotes'}) or $itemnotes ne $item_data_hashref->{'itemnotes'}) {
        $item_changes->{'itemnotes'} = $itemnotes;
    }
} elsif ($itemlost ne $item_data_hashref->{'itemlost'}) {
    $item_changes->{'itemlost'} = $itemlost;
    $cancel_reserves = 1;
} elsif ($wthdrawn ne $item_data_hashref->{'wthdrawn'}) {
    $item_changes->{'wthdrawn'} = $wthdrawn;
} elsif ($damaged ne $item_data_hashref->{'damaged'}) {
    $item_changes->{'damaged'} = $damaged;
    $cancel_reserves = 1 if (!C4::Context->preference('AllowHoldsOnDamagedItems'));
} elsif ($otherstatus ne $item_data_hashref->{'otherstatus'}) {
    $item_changes->{'otherstatus'} = $otherstatus;
    undef($item_changes->{'otherstatus'}) if ($otherstatus eq '');
} elsif ($suppress ne $item_data_hashref->{'suppress'}) {
    $item_changes->{'suppress'} = $suppress;
} else {
    #nothings changed, so do nothing.
    print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");
	exit;
}

ModItem($item_changes, $biblionumber, $itemnumber);
my $issue = GetItemIssue($itemnumber);
my $lost_item = C4::LostItems::GetLostItem($itemnumber);
my $issues = GetItemIssues($itemnumber, 1);
my $lostreturned_issue;
foreach my $issue_ref (@$issues) {
  if ($issue_ref->{'itemnumber'} eq $itemnumber) {
    $lostreturned_issue = $issue_ref;
    last;
  }
}

# Cancel item specific reserves if changing to non-holdable status
if ($cancel_reserves) {
   my %p = ('itemnumber',$itemnumber);
   my $r = C4::Reserves::ItemReservesAndOthers($itemnumber);
   if ($$r{onlyiteminbib}) { 
      $p{biblionumber} = $biblionumber;
      delete($p{itemnumber});
   }
   C4::Reserves::CancelReserves(\%p);
}

# If the item is being made lost, charge the patron the lost item charge and
# create a lost item record
if($issue && $itemlost){
   ## FIXME: move this business logic to a single subroutine in a *.pm -hQ
    ModItemLost( $biblionumber, $itemnumber, $itemlost );
    C4::Accounts::chargelostitem($itemnumber) if ($itemlost==1); # check item in and charge the lost item fee if itemlost == 1
    ## dupecheck is performed in the function
    my $id = C4::LostItems::CreateLostItem(
      $item_data_hashref->{itemnumber},
      $issue->{borrowernumber}
    );

    ## Claims Returned
    if ($itemlost==C4::Context->preference('ClaimsReturnedValue')) {
       C4::Accounts::makeClaimsReturned($id,1);
    }
    else {
       C4::Accounts::makeClaimsReturned($id,0);
    }
}
# If the item is being marked found, refund the patron the lost item charge,
# apply the maxfine charge, and delete the lost item record
elsif ($lost_item && $itemlost==0) {
    DeleteLostItem($lost_item->{id}); # item's no longer lost, so delete the lost item record
    if (C4::Context->preference('RefundReturnedLostItem')) {
        C4::Circulation::FixAccountForLostAndReturned($itemnumber); # credit the charge for losing this item
    }
    # Charge the maxfine
    if (C4::Context->preference('ApplyMaxFineWhenLostItemChargeRefunded') && C4::Context->preference('RefundReturnedLostItem')) {
        my $borrower = GetMember($lostreturned_issue->{borrowernumber},'borrowernumber');
        my ($circ_policy) = C4::Circulation::GetIssuingRule($borrower->{categorycode},$lost_item->{itemtype},$lostreturned_issue->{branchcode});
        if ($circ_policy->{max_fine}) {
            C4::Accounts::manualinvoice(
               borrowernumber => $lostreturned_issue->{borrowernumber},
               itemnumber     => $itemnumber, 
               description    => 'Max overdue fine', 
               accounttype    => 'F', 
               amount         => $circ_policy->{max_fine}
            );
        }
    }
}

print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");
