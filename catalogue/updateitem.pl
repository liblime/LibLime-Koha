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
use Koha;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Circulation;
use C4::Accounts;
use C4::Reserves;
use C4::LostItems;
use C4::Members;

my $cgi= CGI->new();

my ($loggedinuser, $cookie, $sessionID) = checkauth($cgi, 0, {circulate => '*'}, 'intranet');

my $biblionumber    = $cgi->param('biblionumber');
my $itemnumber      = $cgi->param('itemnumber');
my $biblioitemnumber= $cgi->param('biblioitemnumber');
my $itemlost        = $cgi->param('itemlost');
my $itemnotes       = $cgi->param('itemnotes');
my $wthdrawn        = $cgi->param('wthdrawn');
my $damaged         = $cgi->param('damaged');
my $otherstatus     = $cgi->param('otherstatus') // '';
my $suppress        = $cgi->param('suppress');
my $confirm         = $cgi->param('confirm');

my $item_data_hashref = GetItem($itemnumber, undef);
for ($damaged,$itemlost,$wthdrawn,$suppress) { if (!$_ or ($_ eq "")) { $_ = 0;} }

# modify MARC item if input differs from items table.
my $item_changes = {};
my $cancel_reserves = 0;
if (defined $itemnotes) { # i.e., itemnotes parameter passed from form
    if ((not defined $item_data_hashref->{'itemnotes'}) or $itemnotes ne $item_data_hashref->{'itemnotes'}) {
        $item_changes->{'itemnotes'} = $itemnotes;
    }
} elsif ($itemlost ne $item_data_hashref->{'itemlost'}) {
    $item_changes->{'itemlost'} = $itemlost;
} elsif ($wthdrawn ne $item_data_hashref->{'wthdrawn'}) {
    $item_changes->{'wthdrawn'} = $wthdrawn;
} elsif ($damaged ne $item_data_hashref->{'damaged'}) {
    $item_changes->{'damaged'} = $damaged;
    $cancel_reserves = 1 if (!C4::Context->preference('AllowHoldsOnDamagedItems'));
} elsif ($otherstatus ne ($item_data_hashref->{'otherstatus'} // '')) {
    $item_changes->{'otherstatus'} = $otherstatus;
    if (!$otherstatus) {
      undef($item_changes->{'otherstatus'});
    }
    elsif (my $stat = C4::Items::GetOtherStatusWhere(statuscode=>$otherstatus)) {
      C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber) if !$$stat{holdsfilled};
    }
} elsif ($suppress ne $item_data_hashref->{'suppress'}) {
    $item_changes->{'suppress'} = $suppress;
} else {
    #nothing changed, so do nothing.
    print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");
    exit;
}
if ($cgi->param('force_lostcharge_borrowernumber')) {
   C4::LostItems::CreateLostItem(
      $item_data_hashref->{itemnumber},
      $cgi->param('force_lostcharge_borrowernumber'),
   );
}

my $issue      = GetItemIssue($itemnumber);
my $lostitem   = C4::LostItems::GetLostItem($itemnumber);

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
# create a lost item record.  also, if cron is not running, calculate overdues
my $crval = C4::Context->preference('ClaimsReturnedValue');
if (($issue || $lostitem) && $itemlost) {  
   ## dupecheck is performed in the function
   my $id = $$lostitem{id} || C4::LostItems::CreateLostItem(
      $item_data_hashref->{itemnumber},
      $$issue{borrowernumber}
   );
   ## charge the lost item fee for LOST value 1 BEFORE checking in item
   if ($itemlost==1) {
      C4::Accounts::chargelostitem($itemnumber);
   }
   elsif ($crval) { ## Claims Returned
      if ($itemlost==$crval) {
         if (C4::Accounts::makeClaimsReturned($id,1)) {
            ## do nothing
         }
         else {
            C4::LostItems::DeleteLostItem($id);
            print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr#item$itemnumber");
            exit;
         }
      }
      elsif (($$item_data_hashref{itemlost}==$crval)
         && ($itemlost != $$item_data_hashref{itemlost})) { # changing from claims returned to something else
         C4::Accounts::makeClaimsReturned($id,0,1);
      }
   }

   if (C4::Context->preference('MarkLostItemsReturned') && $issue) {
      #C4::Circulation::MarkIssueReturned($$issue{borrowernumber},$itemnumber)
      ## update: AddIssue() will figure out the overdue fine, using today as returndate, 
      ## temporarily setting items.itemlost to nada
      C4::Circulation::AddReturn(
         $item_data_hashref->{barcode},
         undef,  # branch
         0,      # exemptfine
         0,      # dropbox,
         undef,  # returndate
         1,      # tolost
      );
      ## is checked in
      $item_changes->{onloan} = undef;
   }
}
elsif ($itemlost == $crval) { # not charged lost to patron, want make claims returned on overdue
   my($oi,$acc) = C4::LostItems::tryClaimsReturned($item_data_hashref);
   if ($oi && $acc) {
      print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_charged"
         . "&oiborrowernumber=$$oi{borrowernumber}&accountno=$$acc{accountno}#item$itemnumber");
      exit;
   }
   elsif ($oi) {
       print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_notcharged"
         . "&oiborrowernumber=$$oi{borrowernumber}#item$itemnumber");
      exit;    
   }
   else {
      print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_nooi#item$itemnumber");
      exit;
   }
}
elsif ($itemlost && !$lostitem && !$issue && ($itemlost==1)) {
   print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nolc_noco#item$itemnumber");
   exit;    
}
elsif ($lostitem && !$itemlost) {
	## If the item is being marked found, refund the patron the lost item charge,
	## and delete the lost item record if syspref MarkLostItemsReturned is ON
	if ($issue) {
		C4::Circulation::FixAccountForLostAndReturned($itemnumber,$issue,$lostitem->{id});
	}
	else { ## bad legacy data: item not currently checked out but linked as lost to patron
		## remove from patron's Lost Items
		C4::LostItems::DeleteLostItemByItemnumber($itemnumber);
   }
}

ModItem($item_changes, $biblionumber, $itemnumber) if $item_changes;
print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");
