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

my $itemnumber      = $cgi->param('itemnumber');
my $confirm         = $cgi->param('confirm');

# This script updates only one value at a time.
my $param;
my $new_value;
my $statuses = { itemlost    => 0,
                 itemnotes   => '',
                 wthdrawn    => 0,
                 damaged     => 0,
                 otherstatus => undef,
                 suppress    => 0
               };  # nullish values.
               
for (keys %$statuses){
    if(defined($cgi->param($_))){
        $param = $_;
        $new_value = $cgi->param($_) || $statuses->{$_};
    }
}

my @params = $cgi->param();

my $item_data_hashref = GetItem($itemnumber, undef);

my $biblionumber = $item_data_hashref->{biblionumber};


my $side_effects = {
    damaged => sub { 
        C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber);
        # Cancel item specific reserves if changing to non-holdable status
        if (!C4::Context->preference('AllowHoldsOnDamagedItems')){
            my %p = ('itemnumber',$itemnumber);
            my $r = C4::Reserves::ItemReservesAndOthers($itemnumber);
            if ($$r{onlyiteminbib}) { 
                $p{biblionumber} = $biblionumber;
                delete($p{itemnumber});
            }
            C4::Reserves::CancelReserves(\%p);            
        }
    }, otherstatus => sub {
        my $status = shift;
        if (my $stat = C4::Items::GetOtherStatusWhere(statuscode=>$status)) {
            C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber) if !$$stat{holdsfilled};
        } 
    }, itemlost => \&handle_lost
    
};

if ($cgi->param('force_lostcharge_borrowernumber')) {
   C4::LostItems::CreateLostItem( $item_data_hashref->{itemnumber}, $cgi->param('force_lostcharge_borrowernumber') );
}

$side_effects->{$param}->($new_value, $item_data_hashref) if exists $side_effects->{$param};

ModItem({$param => $new_value}, $biblionumber, $itemnumber);
print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");


sub handle_lost{
    my $itemlost = shift || 0;
    my $item_data_hashref = shift;
    
    my $issue      = GetItemIssue($item_data_hashref->{itemnumber});
    my $lostitem   = C4::LostItems::GetLostItem($item_data_hashref->{itemnumber});

    # If the item is being made lost, charge the patron the lost item charge and
    # create a lost item record.  also, if cron is not running, calculate overdues
    
    my $crval = C4::Context->preference('ClaimsReturnedValue');
    C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber) if $itemlost;
    if (($issue || $lostitem) && $itemlost) {  
       ## dupecheck is performed in the function
       my $id = $$lostitem{id} || C4::LostItems::CreateLostItem(
          $item_data_hashref->{itemnumber},
          $$issue{borrowernumber}
       );
       ## note chargelostitem also marks issue returned.  sometimes we don't have an issue.
       ## it should just take an issue_id as param instead.
       if ($itemlost==1) {
           use DDP; warn p $issue;
        #  C4::Accounts::chargelostitem($itemnumber);
       }
       elsif ($crval) { ## Claims Returned
          if ($itemlost==$crval) {
             if (C4::Accounts::makeClaimsReturned($id,1)) {
                ## do nothing
             }
             else {
                C4::LostItems::DeleteLostItem($id);
 # FIXME -- $cgi IS OUT of scope...
 # Do we really need to have two scripts here ?
 # Lost Item handling is dependent on new SCLS-sponsored changes;
 # This is broken until that work is done.
 # Either compress this and make it anonymous or pass $cgi.
 
 #               print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr#item$itemnumber");
                exit;
             }
          }
          elsif (($$item_data_hashref{itemlost}==$crval)
             && ($itemlost != $$item_data_hashref{itemlost})) { # changing from claims returned to something else
             C4::Accounts::makeClaimsReturned($id,0,1);
          }
       }
    
       if ($issue) {
          if( $issue->{'overdue'} ){
            C4::Overdues::ApplyFine($issue);  # i.e. apply fine to today.  ## This should be customizable.
          }
    
    #      $item_changes->{onloan} = undef;
    # FIXME: RESTORE ^^^^
       }
    }
    elsif ($itemlost == $crval) { # not charged lost to patron, want make claims returned on overdue
       my($oi,$acc) = C4::LostItems::tryClaimsReturned($item_data_hashref);
#       if ($oi && $acc) {
#          print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_charged"
#             . "&oiborrowernumber=$$oi{borrowernumber}&accountno=$$acc{accountno}#item$itemnumber");
#          exit;
#       }
#       elsif ($oi) {
#           print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_notcharged"
#             . "&oiborrowernumber=$$oi{borrowernumber}#item$itemnumber");
#          exit;    
#       }
#       else {
#          print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nocr_nooi#item$itemnumber");
#          exit;
#       }
    }
    elsif ($itemlost && !$lostitem && !$issue && ($itemlost==1)) {
        # For some reason, don't allow the item to be set to lost (1) unless there is a patron who can take a lost item charge.
 #      print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nolc_noco#item$itemnumber");
       exit;    
    }
    elsif ($lostitem && !$itemlost) {
    	## If the item is being marked found, refund the patron the lost item charge,
    	## and delete the lost item record
    	if ($issue) {
    		C4::Accounts::creditlostitem($issue);		
    	}
    	## remove from patron's Lost Items
    	# FIXME: Comments in C4::Circulation suggest that staff can choose to leave a lost item linked
    	#   So which is right?
    	# And it's probably not a good idea to delete by itemnumber if itemnumber isn't guaranteed unique.
    	C4::LostItems::DeleteLostItemByItemnumber($itemnumber);
    
    }
}

