#!/usr/bin/env perl

# Copyright 2000-2003 Katipo Communications
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
use C4::Koha;
use CGI;
use C4::Biblio;
use C4::Items;
use C4::Branch;
use C4::Acquisition;
use C4::Output;             # contains gettemplate
use C4::Auth;
use C4::Serials;
use C4::Dates qw/format_date/;
use C4::Circulation;  # to use itemissues
use C4::Search;		# enabled_staff_search_views

my $query=new CGI;

my ($template, $loggedinuser, $cookie) = get_template_and_user({
    template_name   => 'catalogue/moredetail.tmpl',
    query           => $query,
    type            => "intranet",
    authnotrequired => 0,
    flagsrequired   => {catalogue => '*'},
    });

# get variables

my $biblionumber=$query->param('biblionumber');
my $title=$query->param('title');
my $itemnumber=$query->param('itemnumber');
my $updatefail = $query->param('updatefail');
my $bibdata=GetBiblioData($biblionumber);
my $branches = C4::Branch::GetBranches();

my $fw = GetFrameworkCode($biblionumber);
my @items= GetItemsInfo($biblionumber);
my $count=@items;
$bibdata->{'count'}=$count;

my $itemtypes = GetItemTypes;

# dealing w/ item ownership
my $restrict = C4::Context->preference('EditAllLibraries') ?undef:1;
my(@worklibs,%br);
if ($restrict) {
   use C4::Members;
   @worklibs = C4::Members::GetWorkLibraries($loggedinuser);
   $template->param('restrict'=>$restrict);
   foreach(@worklibs) { $br{$_} = 1 } # this is better than grep
}

$bibdata->{'itemtypename'} = $itemtypes->{$bibdata->{'itemtype'}}->{'description'};
($itemnumber) and @items = (grep {$_->{'itemnumber'} == $itemnumber} @items);
my @tmpitems;
my %avc = (
   damaged  => GetAuthValCode('items.damaged' ,$fw),
);


my @fail = qw(nolc_noco);
foreach my $item (@items){
    if ($$item{itemlost}) {
        if (my $lostitem = C4::LostItems::GetLostItem($$item{itemnumber})) {
            my $lostbor = C4::Members::GetMember($$lostitem{borrowernumber});
            $item->{lostby_date} = C4::Dates->new($$lostitem{date_lost},'iso')->output;
            $item->{lostby_name} = "$$lostbor{firstname} $$lostbor{surname}";
            $item->{lostby_borrowernumber} = $$lostitem{borrowernumber};
            $item->{lostby_cardnumber} = $$lostbor{cardnumber};
            $item->{lostby_claims_returned} = $$lostitem{claims_returned};
        }
    }
    if ($updatefail && ($$item{itemnumber} ~~ $itemnumber)) {
        $item->{"updatefail_$updatefail"} = 1;
        if ($updatefail ~~ @fail) {
            my $oldiss = C4::Circulation::GetOldIssue($itemnumber) // {};
            if ($$oldiss{borrowernumber}) { # may be anonymised
               my $lastbor = C4::Members::GetMember($$oldiss{borrowernumber});
               $$item{lastbor_name} = "$$lastbor{firstname} $$lastbor{surname}";
               $$item{lastbor_returndate} = C4::Dates->new($$oldiss{returndate},'iso')->output;
               $$item{lastbor_borrowernumber} = $$oldiss{borrowernumber};
               $$item{lastbor_cardnumber}     = $$lastbor{cardnumber};
            }
        }
    }
    my $itemlost_values = C4::Items::get_itemlost_values();

    my @itemlostloop = map { {  value => $_,
                                lib => $itemlost_values->{$_},
                                selected => ($_ ~~ {$item->{itemlost}//''}) ? 1:0
                                }
                            } keys %$itemlost_values;
    $item->{itemlostloop} = \@itemlostloop;
    $item->{itemdamagedloop} = GetAuthorisedValues($avc{damaged}, $item->{damaged})  if $avc{damaged};
    $item->{itemstatusloop} = GetOtherItemStatus($item->{'otherstatus'});
    $item->{'itype'} = $itemtypes->{$item->{'itype'}}->{'description'}; 
    $item->{'replacementprice'}=sprintf("%.2f", $item->{'replacementprice'});
    $item->{'datelastborrowed'}= format_date($item->{'datelastborrowed'});
    $item->{'dateaccessioned'} = format_date($item->{'dateaccessioned'});
    $item->{'datelastseen'} = format_date($item->{'datelastseen'});
    $item->{'copyvol'} = $item->{'copynumber'};

    if (C4::Context->preference("IndependantBranches")) {
        #verifying rights
        my $userenv = C4::Context->userenv();
        unless (($userenv->{'flags'} == 1) or ($userenv->{'branch'} eq $item->{'homebranch'})) {
                $item->{'nomod'}=1;
        }
    }

    $item->{'homebranchname'} = GetBranchName($item->{'homebranch'});
    $item->{'holdingbranchname'} = GetBranchName($item->{'holdingbranch'});
    if ($item->{'datedue'}) {
        $item->{'datedue'} = format_date($item->{'datedue'});
        $item->{'issue'}= 1;
    } else {
        $item->{'issue'}= 0;
    }

    # item ownership
    if ($restrict && !$br{$$item{homebranch}}) {
         $$item{notmine} = 1;
    }
    
    # Circ status (populates item-status.inc)
    my $ItemBorrowerReserveInfo;
    my $hold = C4::Reserves::GetPendingReserveOnItem($item->{itemnumber});
    if ($hold) {
        my $ItemBorrowerReserveInfo     = GetMember($hold->{borrowernumber});
        $item->{reservedate}            = $hold->{reservedate};
        $item->{waitingdate}            = $hold->{waitingdate};
        $item->{ReservedForBorrowernumber} = $hold->{borrowernumber};
        $item->{ReservedForSurname}     = $ItemBorrowerReserveInfo->{'surname'};
        $item->{ReservedForFirstname}   = $ItemBorrowerReserveInfo->{'firstname'};
        $item->{cardnumber}             = $ItemBorrowerReserveInfo->{'cardnumber'};
    }

    # Check the transit status
    my ( $transfertwhen, $transfertfrom, $transfertto ) = C4::Circulation::GetTransfers($item->{itemnumber});
    if ( defined( $transfertwhen ) && ( $transfertwhen ne '' ) ) {
        $item->{transfersince} = $transfertwhen;
        $item->{transferfrom} = $branches->{$transfertfrom}{branchname};
        $item->{transferto}   = $branches->{$transfertto}{branchname};
    }
    $item->{available} = ! $item->{itemnotforloan}
                        && !$item->{onloan}
                        && !$item->{itemlost}
                        && !$item->{wthdrawn}
                        && !$item->{damaged}
                        && !$item->{suppress}
                        && !$item->{otherstatus}
                        && !$item->{reservedate}
                        && !$item->{transfersince};
    
    push @tmpitems, $item;
}

@items = @tmpitems;

$template->param(count => $bibdata->{'count'},
	C4::Search::enabled_staff_search_views,
);
$template->param(BIBITEM_DATA => [ $bibdata ]);
$template->param(ITEM_DATA => \@items);
$template->param(moredetailview => 1);
$template->param(loggedinuser => $loggedinuser);
$template->param(biblionumber => $biblionumber);
$template->param(itemnumber => $itemnumber);
$template->param(additemnumber => $itemnumber || $items[0]->{itemnumber} ); # for add-item link.
$template->param(ONLY_ONE => 1) if ( $itemnumber && $count != @items );
$template->param(AllowHoldsOnDamagedItems => C4::Context->preference('AllowHoldsOnDamagedItems'));
output_html_with_http_headers $query, $cookie, $template->output;

