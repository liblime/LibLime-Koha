#!/usr/bin/env perl


#writen 2/1/00 by chris@katipo.oc.nz
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

=head1 request.pl

script to place reserves/requests

=cut

use strict;
use warnings;
use C4::Branch; # GetBranches get_branchinfos_of
use CGI;
use List::MoreUtils qw/uniq/;
use Date::Calc qw/Date_to_Days/;
use C4::Output;
use C4::Auth;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::Koha;
use C4::Circulation;
use C4::Dates qw/format_date/;
use C4::Members;
use C4::Accounts;
use C4::Search;		# enabled_staff_search_views

my $dbh = C4::Context->dbh;
my $sth;
my $input = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "reserve/request.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reserveforothers => '*' },
    }
);

my $searchtohold   = $input->param('searchtohold');
my $close_greybox  = $input->param('close_greybox');
my $borrowernumber = $input->param('borrowernumber');
$template->param(
   searchtohold  =>$searchtohold,
   close_greybox =>$close_greybox,
   borrowernumber=>$borrowernumber,
);

my $action = $input->param('action');
$action = '' if not defined $action;
if ( $action eq 'suspend' ) {
  my $resumedate = $input->param('resumedate');
  
  if ( $resumedate =~ m/(0[1-9]|1[0-2])\/(0[1-9]|[12]\d|3[01])\/(\d{4})/ ) {
    my @parts = split('/', $resumedate );
    $resumedate = $parts[2] . '-' . $parts[0] . '-' . $parts[1];
  } else {
    $resumedate = '';
  }
  
  SuspendReserve( $input->param('reservenumber'), $resumedate );
} elsif ( $action eq 'resume' ) {
  ResumeReserve( $input->param('reservenumber') );
}

my ($maxholds_warn,$maxamount_warn,$max_shelf_holds_per_day_warn) = 0;

my $multihold = $input->param('multi_hold');
$template->param(multi_hold => $multihold);

# get Branches and Itemtypes and OtherItemStatus
my $branches = GetBranches();
my $itemtypes = GetItemTypes();
my $itemstatuses = GetOtherItemStatus();
    
my $default = C4::Context->userenv->{branch};
my @values;
my %label_of;
    
foreach my $branchcode (sort keys %{$branches} ) {
    push @values, $branchcode;
    $label_of{$branchcode} = $branches->{$branchcode}->{branchname};
}
my $CGIbranch = CGI::scrolling_list(
                                    -name     => 'pickup',
                                    -id          => 'pickup',
                                    -values   => \@values,
                                    -default  => $default,
                                    -labels   => \%label_of,
                                    -size     => 1,
                                    -multiple => 0,
                                   );

# Select borrowers infos
my $findborrower = $input->param('findborrower');
$findborrower = '' unless defined $findborrower;
$findborrower =~ s|,| |g;
my $cardnumber = $input->param('cardnumber') || '';
my $borrowerslist;
my $messageborrower;
my $warnings;
my $messages;

my $date = C4::Dates->today('iso');

if ($findborrower) {
    my ( $count, $borrowers ) =
      SearchMember($findborrower, 'cardnumber', 'web' );

    my @borrowers = @$borrowers;

    if ( $#borrowers == -1 ) {
        $input->param( 'findborrower', '' );
        $messageborrower = "'$findborrower'";
    }
    elsif ( $#borrowers == 0 ) {
        $input->param( 'cardnumber', $borrowers[0]->{'cardnumber'} );
        $cardnumber = $borrowers[0]->{'cardnumber'};
    }
    else {
        $borrowerslist = \@borrowers;
    }
}

if ($cardnumber) {
    my $borrowerinfo = GetMemberDetails( 0, $cardnumber );
    my $cat          = C4::Members::GetCategoryInfo($$borrowerinfo{categorycode});
    my $diffbranch;
    my @getreservloop;
    my $count_reserv = 0;
    my $maxholds;
    my $maxamount;

#   we check the reserves of the borrower, and if he can reserv a document
# FIXME At this time we have a simple count of reservs, but, later, we could improve the infos "title" ...

   my $number_reserves   = GetReserveCount( $borrowerinfo->{'borrowernumber'} ) // 0;
   my $amount_msg        = $$borrowerinfo{flags}{CHARGES}{message} // '';
   my $cat_amount_symbol = '';
   $$cat{holds_block_threshold} //= 0;
   if ($$cat{maxholds} && ($number_reserves >= $$cat{maxholds})) {
      $warnings = 1;
      $maxholds = 1;
      $maxholds_warn = 1;
   }
   if ($$cat{holds_block_threshold}>0 && $amount_msg) {
      if ($$borrowerinfo{flags}{CHARGES}{amount} > $$cat{holds_block_threshold}) {
         $warnings  = 1;
         $maxamount = 1;
         $maxamount_warn = 1;
         ($cat_amount_symbol) = $amount_msg =~ /patron owes (.)\d/i;
      }
   }

    # we check the date expiry of the borrower (only if there is an expiry date, otherwise, set to 1 (warn)
    my $expiry_date = $borrowerinfo->{dateexpiry};
    my $expiry = 0; # flag set if patron account has expired
    if ($expiry_date and $expiry_date ne '0000-00-00' and
            Date_to_Days(split /-/,$date) > Date_to_Days(split /-/,$expiry_date)) {
		$messages = $expiry = 1;
    }
     

    # check if the borrower make the reserv in a different branch
    if ( $borrowerinfo->{'branchcode'} ne C4::Context->userenv->{'branch'} ) {
		$messages = 1;
        $diffbranch = 1;
    }

    $template->param(
                borrowernumber         => $borrowerinfo->{'borrowernumber'},
                borrowersurname        => $borrowerinfo->{'surname'},
                borrowerfirstname      => $borrowerinfo->{'firstname'},
                borrowerstreetaddress  => $borrowerinfo->{'address'},
                borrowercity           => $borrowerinfo->{'city'},
                borrowerphone          => $borrowerinfo->{'phone'},
                borrowermobile         => $borrowerinfo->{'mobile'},
                borrowerfax            => $borrowerinfo->{'fax'},
                borrowerphonepro       => $borrowerinfo->{'phonepro'},
                borroweremail          => $borrowerinfo->{'email'},
                borroweremailpro       => $borrowerinfo->{'emailpro'},
                borrowercategory       => $borrowerinfo->{'category'},

                borrowerreservs        => $count_reserv,
                maxholds               => $maxholds,
                cat_maxholds           => $$cat{maxholds},
                maxamount              => $maxamount,
                amount_msg             => $amount_msg,
                cat_maxamount          => sprintf("%.2f",$$cat{holds_block_threshold}),
                cat_amount_symbol      => $cat_amount_symbol,
                expiry                 => $expiry,
                diffbranch             => $diffbranch,
                messages               => $messages,
		          warnings               => $warnings
    );
}

$template->param(
    messageborrower => $messageborrower,
    DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar(),
    );

my $CGIselectborrower;
if ($borrowerslist) {
    my @values;
    my %labels;

    foreach my $borrower (
        sort {
                $a->{surname}
              . $a->{firstname} cmp $b->{surname}
              . $b->{firstname}
        } @{$borrowerslist}
      )
    {
        push @values, $borrower->{cardnumber};

        no warnings qw(uninitialized);
        if (C4::Context->preference('DisplayInitials')) {
          $labels{ $borrower->{cardnumber} } = sprintf(
              '%s, %s %s ... (%s - %s) ... %s',
              $borrower->{surname},  $borrower->{firstname},
              $borrower->{initials}, $borrower->{cardnumber},
              $borrower->{categorycode}, $borrower->{address},
          );
        }
        else {
          $labels{ $borrower->{cardnumber} } = sprintf(
              '%s, %s ... (%s - %s) ... %s',
              $borrower->{surname},    $borrower->{firstname},
              $borrower->{cardnumber}, $borrower->{categorycode},
              $borrower->{address},
          );
        }
    }

    $CGIselectborrower = CGI::scrolling_list(
        -name     => 'cardnumber',
        -values   => \@values,
        -labels   => \%labels,
        -size     => 7,
        -multiple => 0,
    );
}

# FIXME launch another time GetMemberDetails perhaps until
my $borrowerinfo = GetMemberDetails( 0, $cardnumber );

my @biblionumbers = ();
my $biblionumbers = $input->param('biblionumbers');
if ($multihold) {
    @biblionumbers = split '/', $biblionumbers;
} else {
    if ($input->param('biblionumber') =~ /\s*\|\s*/) {
      my $biblionumbers = $input->param('biblionumber');
      my @biblionums = split /\s*\|\s*/, $biblionumbers;
      my %seen = ();
      foreach my $bibnum (@biblionums) {
        push (@biblionumbers, $bibnum) unless $seen{$bibnum}++;
      }
    }
    else {
      push @biblionumbers, $input->param('biblionumber');
    }
}

my @biblioloop = ();
foreach my $biblionumber (@biblionumbers) {

    my $number_reserves = GetReserveCount( $borrowerinfo->{'borrowernumber'} );    
    if ( C4::Context->preference('UseGranularMaxHolds') ) {
    	my $itemtype;
    	$sth = $dbh->prepare("SELECT itype FROM items WHERE biblionumber = ?");
	$sth->execute($biblionumber);
	($itemtype) = $sth->fetchrow_array;

        my @reservesByItemtype = C4::Reserves::GetReservesByBorrowernumberAndItemtypeOf($borrowerinfo->{'borrowernumber'},$biblionumber);
        my $number_reserves = scalar( @reservesByItemtype );
                                                
    	my $irule = GetIssuingRule($borrowerinfo->{'categorycode'}, $itemtype, C4::Context->userenv->{'branch'} );
    	my $max_holds = $irule->{'max_holds'};    	
    	if ( $max_holds && $number_reserves >= $max_holds ) {
    	  $template->param( warnings => 1 );
    	  $template->param( maxholds => 1);
    	  $template->param( override_required => 1 );
          $maxholds_warn = 1;
    	}
    }

  if ( C4::Context->preference('MaxShelfHoldsPerDay') ) {
    if ( GetAvailableItemsCount( $biblionumber ) ) {
      my $shelf_holds_today = GetReserveCount( $borrowerinfo->{'borrowernumber'}, my $today = 1, my $shelf_holds_only = 1 );
      my $max_shelf_holds_per_day = C4::Context->preference('MaxShelfHoldsPerDay');

      if ( $shelf_holds_today >= $max_shelf_holds_per_day ) {
        $warnings = 1;
        $max_shelf_holds_per_day_warn = 1;
        $template->param( 
          override_required => 1,
          max_shelf_holds_per_day => $max_shelf_holds_per_day
        );
      }
    }	                    
  }

    my %biblioloopiter = ();

    my $dat          = GetBiblioData($biblionumber);

    # get existing reserves .....
    my ( $count, $reserves ) = GetReservesFromBiblionumber($biblionumber,1);
    my $totalcount = $count;
    my $alreadyreserved;

    foreach my $res (@$reserves) {
        if ( defined $res->{found} && $res->{found} eq 'W' ) {
            $count--;
        }

        if ( defined $borrowerinfo && exists $borrowerinfo->{'borrowernumber'} ) {
          if ( $borrowerinfo->{borrowernumber} eq $res->{borrowernumber} ) {
                $warnings = 1;
                $alreadyreserved = 1;
                $biblioloopiter{warn} = 1;
                $biblioloopiter{alreadyres} = 1;
          }
        }
    }

    $template->param( alreadyreserved => $alreadyreserved,
                      messages => $messages,
                      warnings => $warnings );
    
    
    # FIXME think @optionloop, is maybe obsolete, or  must be switchable by a systeme preference fixed rank or not
    # make priorities options
    
    my @optionloop;
    for ( 1 .. $count + 1 ) {
        push(
             @optionloop,
             {
              num      => $_,
              selected => ( $_ == $count + 1 ),
             }
            );
    }
    # adding a fixed value for priority options
    my $fixedRank = $count+1;

    my @branchcodes;
    my %itemnumbers_of_biblioitem;
    my @itemnumbers;
    
    ## $items is array of 'item' table numbers
    if (my $items = get_itemnumbers_of($biblionumber)->{$biblionumber}){
        @itemnumbers  = @$items;
    }
    else {
        $template->param('noitems' => 1);
        $biblioloopiter{noitems} = 1;
    }
    
    ## Hash of item number to 'item' table fields
    my $iteminfos_of = GetItemInfosOf(@itemnumbers);
    
    ## Here we go backwards again to create hash of biblioitemnumber to itemnumbers,
    ## when by definition all of the itemnumber have the same biblioitemnumber
    foreach my $itemnumber (@itemnumbers) {
        my $biblioitemnumber = $iteminfos_of->{$itemnumber}->{biblioitemnumber};
        push( @{ $itemnumbers_of_biblioitem{$biblioitemnumber} }, $itemnumber );
    }
    
    ## Should be same as biblionumber
    my @biblioitemnumbers = keys %itemnumbers_of_biblioitem;
    
    my $notforloan_label_of = get_notforloan_label_of();
    
    ## Hash of biblioitemnumber to 'biblioitem' table records
    my $biblioiteminfos_of  = GetBiblioItemInfosOf(@biblioitemnumbers);
    
    my @bibitemloop;
    
    foreach my $biblioitemnumber (@biblioitemnumbers) {
        my $biblioitem = $biblioiteminfos_of->{$biblioitemnumber};
        my $num_available = 0;
        my $num_override = 0;
        my $num_policy_blocked = 0;
        
        $biblioitem->{description} =
          $itemtypes->{ $biblioitem->{itemtype} }{description} if (defined($biblioitem->{itemtype}));
        $biblioloopiter{description} = $biblioitem->{description};
        $biblioloopiter{itypename} = $biblioitem->{description};
        $biblioloopiter{imageurl} =
          getitemtypeimagelocation('intranet', $itemtypes->{$biblioitem->{itemtype}}{imageurl}) if (defined($biblioitem->{itemtype}));
        
        foreach my $itemnumber ( @{ $itemnumbers_of_biblioitem{$biblioitemnumber} } )    {
            my $item = $iteminfos_of->{$itemnumber};
            
            unless (C4::Context->preference('item-level_itypes')) {
                $item->{itype} = $biblioitem->{itemtype};
            }
            
            $item->{itypename} = $itemtypes->{ $item->{itype} }{description};
            $item->{imageurl} = getitemtypeimagelocation( 'intranet', $itemtypes->{ $item->{itype} }{imageurl} );
            $item->{homebranchname} = $branches->{ $item->{homebranch} }{branchname};
            
            # if the holdingbranch is different than the homebranch, we show the
            # holdingbranch of the document too
            if ( $item->{homebranch} ne $item->{holdingbranch} ) {
                $item->{holdingbranchname} =
                  $branches->{ $item->{holdingbranch} }{branchname};
            }
            
            #   add information
            $item->{itemcallnumber} = $item->{itemcallnumber};
            
            # if the item is currently on loan, we display its return date and
            # change the background color
            my $issues= GetItemIssue($itemnumber);
            if ( $issues->{'date_due'} ) {
                $item->{date_due} = format_date($issues->{'date_due'});
                $item->{backgroundcolor} = 'onloan';
            }
            
            # checking reserve
            my ($reservenumber,$reservedate,$reservedfor,$expectedAt) = GetReservesFromItemnumber($itemnumber);
            $$item{reservenumber} = $reservenumber;
            my $ItemBorrowerReserveInfo = GetMember($reservedfor);
            
            if ( defined $reservedate ) {
                $item->{backgroundcolor} = 'reserved';
                $item->{reservedate}     = format_date($reservedate);
                $item->{ReservedForBorrowernumber}     = $reservedfor;
                $item->{ReservedForSurname}     = $ItemBorrowerReserveInfo->{'surname'};
                $item->{ReservedForFirstname}     = $ItemBorrowerReserveInfo->{'firstname'};
                $item->{ExpectedAtLibrary}     = $branches->{$expectedAt}{branchname};
                
            }
            
            # Management of the notforloan document
            if ( $item->{notforloan} ) {
                $item->{backgroundcolor} = 'other';
                $item->{notforloanvalue} =
                  $notforloan_label_of->{ $item->{notforloan} };
            }
            
            # Management of lost or long overdue items
            if ( $item->{itemlost} ) {
                
                # FIXME localized strings should never be in Perl code
                $item->{message} =
                  $item->{itemlost} == 1 ? "(lost)"
                    : $item->{itemlost} == 2 ? "(long overdue)"
                      : "";
                $item->{backgroundcolor} = 'other';
            }

            # Examine items.otherstatus and determine if it can be held
            if ( $item->{otherstatus}) {
              foreach my $istatus (@$itemstatuses) {
                if ($istatus->{statuscode} eq $item->{otherstatus}) {
                  $item->{otherstatus_description} = $istatus->{description};
                  $template->param( otherstatus_description => $item->{otherstatus_description} );
                  if (!$istatus->{holdsallowed}) {
                    $biblioloopiter{warn} = 1;
                    $biblioloopiter{noresstatus} = 1;
                    $item->{noresstatus} = 1;
                    $item->{backgroundcolor} = 'other';
                  }
                  last;
                }
              }
            }

            # Check the transit status
            my ( $transfertwhen, $transfertfrom, $transfertto ) =
              GetTransfers($itemnumber);
            
            if ( defined $transfertwhen && $transfertwhen ne '' ) {
                $item->{transfertwhen} = format_date($transfertwhen);
                $item->{transfertfrom} =
                  $branches->{$transfertfrom}{branchname};
                $item->{transfertto} = $branches->{$transfertto}{branchname};
                $item->{nocancel} = 1;
            }
            
            # If there is no loan, return and transfer, we show a checkbox.
            $item->{notforloan} = $item->{notforloan} || 0;
            
            # if independent branches is on we need to check if the person can reserve
            # for branches they arent logged in to
            if ( C4::Context->preference("IndependantBranches") ) { 
                if (! C4::Context->preference("canreservefromotherbranches")){
                    # cant reserve items so need to check if item homebranch and userenv branch match if not we cant reserve
                    my $userenv = C4::Context->userenv;
                    if ( ($userenv) && ( $userenv->{flags} % 2 != 1 ) ) {
                        $item->{cantreserve} = 1 if ( $item->{homebranch} ne $userenv->{branch} );
                    }
                }
            }
            
            my $branch = C4::Circulation::_GetCircControlBranch($item, $borrowerinfo);
            my $issuingrule = GetIssuingRule($borrowerinfo->{categorycode}, $item->{itype}, $branch);
            my $policy_holdallowed = 1;
            $item->{'holdallowed'} = $issuingrule->{'holdallowed'};

            if (!$issuingrule->{holdallowed}
                || (
                     ($borrowerinfo->{branchcode} && $borrowerinfo->{branchcode} ne $item->{homebranch} ) 
                     && $issuingrule->{holdallowed} == 1
                   )
                ) {
                $policy_holdallowed = 0;
            }
            
            if (IsAvailableForItemLevelRequest($itemnumber) and not $item->{cantreserve}) {
                if (!$policy_holdallowed ) {
					if ( C4::Context->preference( 'AllowHoldPolicyOverride' ) ) {
						$item->{override} = 1;
						$num_override++;
					} else {
						$num_policy_blocked++;
					}
                } elsif (( $policy_holdallowed ) && (!$item->{noresstatus} )) {
                    $item->{available} = 1;
                    $num_available++;
                }
                if ($alreadyreserved && CanHoldMultipleItems($item->{itype},'intranet')) {
                  $template->param( alreadyreserved => undef);
                  $template->param( warnings => undef) if (!$maxholds_warn && !$maxamount_warn && !$max_shelf_holds_per_day_warn)
                }
                elsif ($alreadyreserved) {
                    $item->{available} = undef;
                }
            }
            # If none of the conditions hold true, then neither override nor available is set and the item cannot be checked
            
            # FIXME: move this to a pm
            my ($wdate) = $dbh->selectrow_array(q{
                SELECT waitingdate FROM reserves WHERE borrowernumber=? AND itemnumber=? AND found='W'
                }, undef, $item->{ReservedForBorrowernumber}, $item->{itemnumber});
            $item->{waitingdate} = format_date($wdate);

            if ( BorrowerHasReserve( $borrowerinfo->{'borrowernumber'}, $itemnumber ) ) {
              $item->{available} = 0;
              $item->{override} = 0;
            }
            
            push @{ $biblioitem->{itemloop} }, $item;
        }
        
        if ( $num_override == scalar( @{ $biblioitem->{itemloop} } ) ) { # That is, if all items require an override
            $template->param( override_required => 1 );
        } elsif ( $num_available == 0 ) {
            $template->param( none_available => 1 );
			$template->param( num_policy_blocked => $num_policy_blocked );
            $template->param( warnings => 1 );
            $biblioloopiter{warn} = 1;
            $biblioloopiter{none_avail} = 1;
        }
        push @bibitemloop, $biblioitem;
    }

    # existingreserves building
    my @reserveloop;
    my $populate_option_loop = $template->param('CAN_user_reserveforothers_reorder_holds');
    # pretend all non-T/non-W reserves have an 'S' for sorting purposes
    foreach my $res ( sort { ($a->{found} // 'S') cmp ($b->{found} // 'S') } @$reserves ) {
        my %reserve;

        $reserve{'reservenumber'}   = $res->{'reservenumber'};

        my @optionloop;
        if ($populate_option_loop ) {
            for ( my $i = 1 ; $i <= $totalcount ; $i++ ) {
                push(
                    @optionloop,
                    {
                        num      => $i,
                        selected => ( $i == $res->{priority} ),
                    }
                );
            }
        } else {
            push @optionloop, { num => $res->{priority}, selected => 1, };
        }
        
        if ( defined $res->{'found'} && ( $res->{'found'} eq 'W' || $res->{'found'} eq 'T' ) ) {
            my $item = $res->{'itemnumber'};
            $item = GetBiblioFromItemNumber($item,undef);
            $reserve{'wait'}= 1; 
            $reserve{'holdingbranch'}=$item->{'holdingbranch'};
            $reserve{'biblionumber'}=$item->{'biblionumber'};
            $reserve{'barcodenumber'}   = $item->{'barcode'};
            $reserve{'wbrcode'} = $res->{'branchcode'};
            $reserve{'itemnumber'}  = $res->{'itemnumber'};
            $reserve{'wbrname'} = $branches->{$res->{'branchcode'}}->{'branchname'};
            if($reserve{'holdingbranch'} eq $reserve{'wbrcode'}){
                $reserve{'atdestination'} = 1;
            }
            # set found to 1 if reserve is waiting for patron pickup
            $reserve{'found'} = 1 if $res->{'found'} eq 'W';
            $reserve{'intransit'} = 1 if $res->{'found'} eq 'T';
        } elsif ($res->{priority} > 0) {
            if (defined($res->{itemnumber})) {
                my $item = GetItem($res->{itemnumber});
                $reserve{'itemnumber'}  = $res->{'itemnumber'};
                $reserve{'barcodenumber'}   = $item->{'barcode'};
                $reserve{'item_level_hold'} = 1;
            }
        }
        
        #     get borrowers reserve info
        my $reserveborrowerinfo = GetMember( $res->{'borrowernumber'});
        if (C4::Context->preference('HidePatronName')){
	    $reserve{'hidename'} = 1;
	    $reserve{'cardnumber'} = $reserveborrowerinfo->{'cardnumber'};
	}
        $reserve{suspended}        = (($res->{found} // '') eq 'S') ? 1 : 0;
        $reserve{waitingdate}      = format_date( $res->{waitingdate} );
        $reserve{'date'}           = $res->{'reservedate'};
        $reserve{'borrowernumber'} = $res->{'borrowernumber'};
        $reserve{'biblionumber'}   = $res->{'biblionumber'};
        $reserve{'borrowernumber'} = $res->{'borrowernumber'};
        $reserve{'firstname'}      = $reserveborrowerinfo->{'firstname'};
        $reserve{'surname'}        = $reserveborrowerinfo->{'surname'};	    
        $reserve{'notes'}          = $res->{'reservenotes'};
        $reserve{'wait'}           =
          ( ( defined $res->{'found'} and $res->{'found'} eq 'W' ) or ( $res->{'priority'} eq '0' ) );
        $reserve{'constrainttypea'} = ( $res->{'constrainttype'} eq 'a' );
        $reserve{'constrainttypeo'} = ( $res->{'constrainttype'} eq 'o' );
        $reserve{'voldesc'}         = $res->{'volumeddesc'};
        $reserve{'ccode'}           = $res->{'ccode'};
        $reserve{'barcode'}         = $res->{'barcode'};
        $reserve{'priority'}    = $res->{'priority'};
        $reserve{'branchloop'} = GetBranchesLoop($res->{'branchcode'}, 0);
        $reserve{'optionloop'} = \@optionloop;
        $reserve{'reservenumber'} = $res->{'reservenumber'};
        
        push( @reserveloop, \%reserve );
    }

    # get the time for the form name...
    my $time = time();
    
    $template->param(
                     CGIbranch   => $CGIbranch,

                     time        => $time,
                     fixedRank   => $fixedRank,
                    );
    
    # display infos
    $template->param(
                     optionloop        => \@optionloop,
                     bibitemloop       => \@bibitemloop,
                     date              => $date,
                     biblionumber      => $biblionumber,
                     findborrower      => $findborrower,
                     cardnumber        => $cardnumber,
                     title             => $dat->{title},
                     author            => $dat->{author},
                     holdsview => 1,
                     C4::Search::enabled_staff_search_views,
                    );
    if (defined $borrowerinfo && exists $borrowerinfo->{'branchcode'}) {
        $template->param(
                     borrower_branchname => $branches->{$borrowerinfo->{'branchcode'}}->{'branchname'},
                     borrower_branchcode => $borrowerinfo->{'branchcode'},
        );
    }
    $template->param(CGIselectborrower => $CGIselectborrower) if defined $CGIselectborrower;

    $biblioloopiter{biblionumber} = $biblionumber;
    $biblioloopiter{title} = $dat->{title};
    $biblioloopiter{rank} = $fixedRank;
    $biblioloopiter{reserveloop} = \@reserveloop;

    if (@reserveloop) {
        $template->param( reserveloop => \@reserveloop );
    }
    

    push @biblioloop, \%biblioloopiter;
}

$template->param( biblioloop => \@biblioloop );
$template->param( biblionumbers => $biblionumbers );

if ($multihold) {
    $template->param( multi_hold => 1 );
}

if ( C4::Context->preference( 'AllowHoldDateInFuture' ) ) {
    $template->param(
	reserve_in_future         => 1,
	);
}
    
# printout the page
output_html_with_http_headers $input, $cookie, $template->output;
