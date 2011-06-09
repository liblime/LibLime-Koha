#!/usr/bin/env perl 
#-----------------------------------
# Script Name: build_holds_queue.pl
# Description: builds a holds queue in the tmp_holdsqueue table
#-----------------------------------
# FIXME: add command-line options for verbosity and summary
# FIXME: expand perldoc, explain intended logic
# FIXME: refactor all subroutines into C4 for testability

use strict;
use warnings;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin qw($RealBin);
    eval { require "$RealBin/../kohalib.pl" };
}

use C4::Context;
use C4::Reserves;

my %seen = ();
my @f = qw(reservenumber biblionumber itemnumber barcode surname firstname phone 
borrowernumber cardnumber reservedate title itemcallnumber holdingbranch pickbranch 
notes item_level_request queue_sofar);
my @branches = C4::Reserves::getBranchesQueueWeight();

C4::Reserves::CleanupQueue();

## shallow picking skims the top of pending reserves in each bib
HOLD:
foreach my $res (values %{C4::Reserves::GetReservesForQueue() // {}}) {
   ## dupecheck on reservenumber
   ## DupecheckQueue() already filters out holds on shelf (found=non-empty),
   ## priority, and reservedate.
   next HOLD if C4::Reserves::DupecheckQueue($$res{reservenumber});
   my $item;
   ($res,$item) = _pick($res);   
   unless ($item) {
      push @{$seen{$$res{biblionumber}}}, $$res{reservenumber};
      undef $res; # free memory
      next HOLD;
   }
   die "Bad logic: expected itemnumber" unless $$item{itemnumber};
   delete $seen{$$res{biblionumber}}; # fill one hold per bib
   _save($res,$item);
}

## drill vertically down the bib and keep trying to fill a hold.
## quit on first fill or until exhausted in bib.
BIB:
foreach my $biblionumber(keys %seen) {
   foreach my $res(values %{C4::Reserves::GetReservesForQueue($biblionumber,@{$seen{$biblionumber}}) // {}}) {
      next BIB if _save(_pick($res));
   }
}

sub _save
{
   my($res,$item) = @_;
   return unless $item;
   foreach(keys %$item) { $$res{$_} = $$item{$_} }
   my %new = ();
   foreach(@f) { $new{$_} = $$res{$_} }
   $new{queue_sofar} = $new{holdingbranch};
   C4::Reserves::SaveHoldInQueue(%new);
   return 1;
}

sub _pick
{
   my $res = shift;
   my $item;
   if ($$res{itemnumber}) {
      $$res{item_level_request} = 1;
      ## (1) we have an item, get its barcode,title,itemcallnumber,
      ## holdingbranch.  borrower is passed to check issuing rules.
      $item = C4::Reserves::GetItemForQueue($res);
   }
   else {   ## (2)
      $$res{item_level_request} = 0;
      $$res{holdingbranch}      = '';
      ## (a) try to find an item
      $item = C4::Reserves::GetItemForBibPrefill($res,@branches);
      ## (b) do nothing else
   }
   return $res, $item;
}

exit;
__END__


sub GetPendingHoldRequestsForBib {
    my $biblionumber = shift;

    my $dbh = C4::Context->dbh;

    my $request_query = "SELECT biblionumber, borrowernumber, itemnumber, priority, reserves.branchcode, 
                                reservedate, reservenotes, borrowers.branchcode AS borrowerbranch,
                                borrowers.categorycode AS borrowercategory
                         FROM reserves
                         JOIN borrowers USING (borrowernumber)
                         WHERE biblionumber = ?
                         AND found IS NULL
                         AND priority > 0
                         AND reservedate <= CURRENT_DATE()
                         ORDER BY priority";
    my $sth = $dbh->prepare($request_query);
    $sth->execute($biblionumber);

    my $requests = $sth->fetchall_arrayref({});
    return $requests;

}

=head2 GetItemsAvailableToFillHoldRequestsForBib

=over 4

my $available_items = GetItemsAvailableToFillHoldRequestsForBib($biblionumber);

=back

Returns an arrayref of items available to fill hold requests
for the bib identified by C<$biblionumber>.  An item is available
to fill a hold request if and only if:

    * it is not on loan
    * it is not withdrawn
    * it is not marked notforloan
    * it is not damaged (if syspref AllowHoldsOnDamagedItems = Off)
    * it is not currently in transit
    * it is not lost
    * it is not sitting on the hold shelf
    * it is not set to trace

=cut

sub GetItemsAvailableToFillHoldRequestsForBib {
    my $biblionumber = shift;
    my @branches_to_use = @_;

    my $dbh = C4::Context->dbh;

    my $subquery = q|SELECT itemnumber
                     FROM reserves
                     WHERE biblionumber = ?
                     AND itemnumber IS NOT NULL
                     AND (found IS NOT NULL OR priority = 0)
                    |;
    my $item_set = $dbh->selectcol_arrayref($subquery, undef, $biblionumber);
    my $item_set_placeholders = join ',', split(//, '?' x scalar @{$item_set});

    my $items_query = "SELECT itemnumber, homebranch, holdingbranch, itemtypes.itemtype AS itype
                       FROM items ";

    if (C4::Context->preference('item-level_itypes')) {
        $items_query .=   "LEFT JOIN itemtypes ON (itemtypes.itemtype = items.itype) ";
    } else {
        $items_query .=   "JOIN biblioitems USING (biblioitemnumber)
                           LEFT JOIN itemtypes USING (itemtype) ";
    }
    $items_query .= q|WHERE items.notforloan = 0
                      AND biblionumber = ?
                      AND holdingbranch IS NOT NULL
                      AND itemlost = 0
                      AND wthdrawn = 0
                      AND items.onloan IS NULL
                      AND (itemtypes.notforloan IS NULL OR itemtypes.notforloan = 0)
                     |;
    my @params = ($biblionumber);
    $items_query .= " AND damaged = 0" if (!C4::Context->preference('AllowHoldsOnDamagedItems'));
    if (@{$item_set}) {
        $items_query .= " AND itemnumber NOT IN ($item_set_placeholders)";
        push @params, @{$item_set};
    }
    if ($#branches_to_use > -1) {
        $items_query .= " AND holdingbranch IN (" . join (",", map { "?" } @branches_to_use) . ")";
        push @params, @branches_to_use;
    }
    my $sth = $dbh->prepare($items_query);
    $sth->execute(@params);

    my $items = $sth->fetchall_arrayref({});
    $items = [ grep { my @transfers = GetTransfers($_->{itemnumber}); $#transfers == -1; } @$items ]; 
    return $items;
}

=head2 MapItemsToHoldRequests

=over 4

MapItemsToHoldRequests($hold_requests, $available_items);

=back

=cut

sub MapItemsToHoldRequests {
    my $hold_requests = shift;
    my $available_items = shift;
    my @branches_to_use = @_;

    # handle trival cases
    return unless scalar(@$hold_requests) > 0;
    return unless scalar(@$available_items) > 0;

    # identify item-level requests
    my %specific_items_requested = map { $_->{itemnumber} => 1 } 
                                   grep { defined($_->{itemnumber}) }
                                   @$hold_requests;

    # group available items by itemnumber
    my %items_by_itemnumber = map { $_->{itemnumber} => $_ } @$available_items;

    # items already allocated
    my %allocated_items = ();

    # map of items to hold requests
    my %item_map = ();
 
    # figure out which item-level requests can be filled    
    my $num_items_remaining = scalar(@$available_items);
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining == 0;

        # is this an item-level request?
        if (defined($request->{itemnumber})) {
            # fill it if possible; if not skip it
            if (exists $items_by_itemnumber{$request->{itemnumber}} and
                not exists $allocated_items{$request->{itemnumber}}) {
                $item_map{$request->{itemnumber}} = { 
                    borrowernumber => $request->{borrowernumber},
                    biblionumber => $request->{biblionumber},
                    holdingbranch =>  $items_by_itemnumber{$request->{itemnumber}}->{holdingbranch},
                    pickup_branch => $request->{branchcode},
                    item_level => 1,
                    reservedate => $request->{reservedate},
                    reservenotes => $request->{reservenotes},
                };
                $allocated_items{$request->{itemnumber}}++;
                $num_items_remaining--;
            }
        } else {
            # it's title-level request that will take up one item
            $num_items_remaining--;
        }
    }

    # group available items by branch
    my %items_by_branch = ();
    foreach my $item (@$available_items) {
        push @{ $items_by_branch{ $item->{holdingbranch} } }, $item unless exists $allocated_items{ $item->{itemnumber} };
    }

    # now handle the title-level requests
    $num_items_remaining = scalar(@$available_items) - scalar(keys %allocated_items); 
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining <= 0;
        next if defined($request->{itemnumber}); # already handled these

        # look for local match first

        my $pickup_branch = $request->{branchcode};
        my $irule = _get_issuing_rule( $request, $items_by_branch{$pickup_branch}->[0] );
        my $local_holdallowed = (exists $items_by_branch{$pickup_branch} and $irule) ? $irule->{holdallowed} : 0;

        if ($local_holdallowed and
            not (($local_holdallowed == 1 and
                 $request->{borrowerbranch} ne $items_by_branch{$pickup_branch}->[0]->{homebranch}))
           ) {
            my $item = pop @{ $items_by_branch{$pickup_branch} };
            next unless $item;
            delete $items_by_branch{$pickup_branch} if scalar(@{ $items_by_branch{$pickup_branch} }) == 0;
            $item->{itemnumber} //= '';
            $item_map{$item->{itemnumber}} = { 
                                                borrowernumber => $request->{borrowernumber},
                                                biblionumber => $request->{biblionumber},
                                                holdingbranch => $pickup_branch,
                                                pickup_branch => $pickup_branch,
                                                item_level => 0,
                                                reservedate => $request->{reservedate},
                                                reservenotes => $request->{reservenotes},
                                             };
            $num_items_remaining--;
        } else {
            my @pull_branches = ();
            if ($#branches_to_use > -1) {
                @pull_branches = @branches_to_use;
                
                ( @pull_branches ) = GetNextLibraryHoldsQueueWeight( $request->{branchcode} ) if C4::Context->preference('NextLibraryHoldsQueueWeight');
            } else {
                @pull_branches = sort keys %items_by_branch;
            }
            foreach my $branch (@pull_branches) {
                my $irule = _get_issuing_rule( $request, $items_by_branch{$branch}->[0] );
                $local_holdallowed = (exists $items_by_branch{$branch} and $irule) ? $irule->{holdallowed} : 0;
                next unless $local_holdallowed and
                            not (($local_holdallowed == 1 and
                                 $request->{borrowerbranch} ne $items_by_branch{$branch}->[0]->{homebranch}));
                my $item = pop @{ $items_by_branch{$branch} };
                delete $items_by_branch{$branch} if scalar(@{ $items_by_branch{$branch} }) == 0;
                $item_map{$item->{itemnumber}} = { 
                                                    borrowernumber => $request->{borrowernumber},
                                                    biblionumber => $request->{biblionumber},
                                                    holdingbranch => $branch,
                                                    pickup_branch => $pickup_branch,
                                                    item_level => 0,
                                                    reservedate => $request->{reservedate},
                                                    reservenotes => $request->{reservenotes},
                                                 };
                $num_items_remaining--; 
                last;
            }
        }
    }
    return \%item_map;
}

=head2 GetNextLibraryHoldsQueueWeight 

=cut

sub GetNextLibraryHoldsQueueWeight {
    my ( $branchcode ) = @_;
    
    my $weight_list = C4::Context->preference('NextLibraryHoldsQueueWeight');
    
    my @weight_list = split(/,/, $weight_list);
    
    my ( $index ) = grep { $weight_list[$_] eq $branchcode } 0..$#weight_list;
    
    my @new_weight_list;
    
    push( @new_weight_list, @weight_list[ $index, $#weight_list ] ); # First push $branchcode through the end on
    push( @new_weight_list, @weight_list[ 0, $index - 1 ] ); # Then, push what's left of the beginning onto the end
    
    return @new_weight_list;
}

=head2 CreatePickListFromItemMap 

=cut

sub CreatePicklistFromItemMap {
    my $item_map = shift;

     my $dbh = C4::Context->dbh;
   # dupecheck

    my $insert_sql = "
        INSERT IGNORE INTO tmp_holdsqueue (biblionumber,itemnumber,barcode,surname,firstname,phone,borrowernumber,
                                    cardnumber,reservedate,title, itemcallnumber,
                                    holdingbranch,pickbranch,notes, item_level_request)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ";

    ITEM:
    foreach my $itemnumber  (sort keys %$item_map) {
        my $mapped_item = $item_map->{$itemnumber};
        my $biblionumber = $mapped_item->{biblionumber}; 
        my $borrowernumber = $mapped_item->{borrowernumber}; 
        my $pickbranch = $mapped_item->{pickup_branch};
        my $holdingbranch = $mapped_item->{holdingbranch};
        my $reservedate = $mapped_item->{reservedate};
        my $reservenotes = $mapped_item->{reservenotes};
        my $item_level = $mapped_item->{item_level};

        my $item = GetItem($itemnumber);
        my $barcode = $item->{barcode};
        my $itemcallnumber = $item->{itemcallnumber};

        my $borrower = GetMember($borrowernumber);
        my $cardnumber = $borrower->{'cardnumber'};
        my $surname = $borrower->{'surname'};
        my $firstname = $borrower->{'firstname'};
        my $phone = $borrower->{'phone'};
   
        my $bib = GetBiblioData($biblionumber);
        my $title = $bib->{title}; 
        my $sth_load = $dbh->prepare($insert_sql);
        $sth_load->execute($biblionumber, $itemnumber, $barcode, 
         $surname, $firstname, $phone, $borrowernumber,
         $cardnumber, $reservedate, $title, $itemcallnumber,
         $holdingbranch, $pickbranch, $reservenotes, $item_level);
    }
}

=head2 AddToHoldTargetMap

=cut

sub AddToHoldTargetMap {
    my $item_map = shift;
    my $dbh = C4::Context->dbh;

    my $insert_sql = q(
        INSERT INTO hold_fill_targets (
         borrowernumber, biblionumber, itemnumber, 
         source_branchcode, item_level_request)
        VALUES (?, ?, ?, ?, ?)
    );

    ITEM:
    foreach my $itemnumber (keys %$item_map) {
        my $mapped_item = $item_map->{$itemnumber};
        next ITEM if not $itemnumber;
        
        # dupecheck
        my $sth = $dbh->prepare("SELECT 1 FROM hold_fill_targets
         WHERE itemnumber = ?") || die $dbh->errstr();
        $sth->execute(
         $itemnumber,
        ) || die $dbh->errstr();
        my($dupe) = ($sth->fetchrow_array)[0];
        next ITEM if $dupe;
        
        my $sth_insert = $dbh->prepare($insert_sql);
        $sth_insert->execute(
         $mapped_item->{borrowernumber}, 
         $mapped_item->{biblionumber}, 
         $itemnumber,
         $mapped_item->{holdingbranch}, 
         $mapped_item->{item_level});
    }
}

=head2 _get_branches_to_pull_from

Query system preferences to get ordered list of
branches to use to fill hold requests.

=cut

sub _get_branches_to_pull_from {
    my @branches_to_use = ();
  
    my $static_branch_list = C4::Context->preference("StaticHoldsQueueWeight");
    if ($static_branch_list) {
        @branches_to_use = map { s/^\s+//; s/\s+$//; $_; } split /,/, $static_branch_list;
    }

    @branches_to_use = shuffle(@branches_to_use) if  C4::Context->preference("RandomizeHoldsQueueWeight");

    return @branches_to_use;
}

=head2 _get_issuing_rule

Looks up the issuing rule (for holdallowed) for a given request and item.

=cut

sub _get_issuing_rule {
    my ($request, $item) = @_;
    my ($branch, $categorycode, $itemtype) =
        ($item->{'holdingbranch'}, $request->{'borrowercategory'}, $item->{'itype'});

    return GetIssuingRule( $categorycode, $itemtype, $branch );
}
