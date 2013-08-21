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

# NOTE: This script updates only ONE value at a time.
my $status_to_update;
my $new_value;
my $statuses = { itemlost    => undef,
                 itemnotes   => '',
                 wthdrawn    => 0,
                 damaged     => 0,
                 otherstatus => undef,
                 suppress    => 0
               };  # nullish values.

for (keys %$statuses){
    if(defined($cgi->param($_))){
        $status_to_update = $_;
        $new_value = $cgi->param($_) || $statuses->{$_};
    }
}

my @params = $cgi->param();

my $item_data_hashref = GetItem($itemnumber, undef);

my $biblionumber = $item_data_hashref->{biblionumber};

# dispatch table to handle various status changes.
my $side_effects = {
    otherstatus => sub {
        my $status = shift;
        if (my $stat = C4::Items::GetOtherStatusWhere(statuscode=>$status)) {
            C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber) if !$$stat{holdsfilled};
        } 
    },
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
    },
    itemlost => sub {
        my $lostval = shift || undef;
        my $item_data_hashref = shift;

        my $issue      = GetItemIssue($item_data_hashref->{itemnumber});
        my $lostitem   = C4::LostItems::GetLostItem($item_data_hashref->{itemnumber});

        # If the item is being made lost, charge the patron the lost item charge and create a lost item record.

        C4::Reserves::RmFromHoldsQueue(itemnumber=>$itemnumber) if $lostval;

        # FIXME:  if we're allowed to leave items in the lost_items table after they are found,
        # then this check is wrong; $lostitem could be the wrong entry.

        if (($issue || $lostitem) && $lostval eq 'lost') {  
            ## dupecheck is performed in the function
            my $id = $$lostitem{id} || C4::LostItems::CreateLostItem(
                $item_data_hashref->{itemnumber},
                $$issue{borrowernumber}
            );
            ## note if item is issued, chargelostitem marks issue returned.# If not, it will waive overdue fines.
            C4::Accounts::chargelostitem($id);

        } elsif ($lostval && !$lostitem && !$issue && ($lostval eq 'lost')) {
           # Do not allow the item to be set to 'lost' unless there is a patron who can take a lost item charge.
           print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber&updatefail=nolc_noco#item$itemnumber");
           exit;    
        } elsif ($lostitem && $lostval ne 'lost') {
            ## If the item is being marked found, refund the patron the lost item charge,
            ## and delete the lost item record #  User should have been warned on form submit.
            C4::Accounts::credit_lost_item($lostitem->{id});        
            C4::LostItems::DeleteLostItem($lostitem->{id});
        }
    }

};

if ($cgi->param('force_lostcharge_borrowernumber')) {
   C4::LostItems::CreateLostItem( $item_data_hashref->{itemnumber}, $cgi->param('force_lostcharge_borrowernumber') );
}

$side_effects->{$status_to_update}->($new_value, $item_data_hashref) if exists $side_effects->{$status_to_update};

ModItem({$status_to_update => $new_value}, $biblionumber, $itemnumber);
print $cgi->redirect("moredetail.pl?biblionumber=$biblionumber&itemnumber=$itemnumber#item$itemnumber");


