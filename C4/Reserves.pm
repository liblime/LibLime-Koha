package C4::Reserves;

# Copyright 2000-2002 Katipo Communications
#           2006 SAN Ouest Provence
#           2007 BibLibre Paul POULAIN
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
use Carp;

use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Search;
use C4::Circulation;
use C4::Accounts;
use C4::Dates;
use C4::Calendar;
use C4::Stats;

# for _koha_notify_reserve
use C4::Members::Messaging;
use C4::Members qw();
use C4::Letters;
use C4::Branch qw( GetBranchDetail );
use C4::Dates qw( format_date_in_iso );
use C4::Debug;
use Date::Calc qw(Today Add_Delta_Days);
use Time::Local;
use DateTime;
use DateTime::Format::DateParse;
        
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

%C4::Reserves::found = (
   'F'   => 'Filled',      # hold completed at checkout
   'S'   => 'Suspended',
   'T'   => 'In Transit',
   'W'   => 'Waiting',     # hold "filled" at checkin
);

=head1 NAME

C4::Reserves - Koha functions for dealing with reservation.

=head1 SYNOPSIS

  use C4::Reserves;

=head1 DESCRIPTION

  this modules provides somes functions to deal with reservations.
  
  Reserves are stored in reserves table.
  The following columns contains important values :
  - priority >0      : then the reserve is at 1st stage, and not yet affected to any item.
             =0      : then the reserve is being dealed
  - found : NULL       : means the patron requested the 1st available, and we haven't choosen the item
            T(ransit)  : the reserve is linked to an item but is in transit to the pickup branch
            W(aiting)  : the reserve is linked to an item, is at the pickup branch, and is waiting on the hold shelf
            F(inished) : the reserve has been completed, and is done
            R(trace)   : the reserve is set to 'trace' because it apparently can't be fulfilled
            S(uspend)  : the reserve is suspended
  - itemnumber : empty : the reserve is still unaffected to an item
                 filled: the reserve is attached to an item
  The complete workflow is :
  ==== 1st use case ====
  patron request a document, 1st available :                      P >0, F=NULL, I=NULL
  a library having it run "transfertodo", and clic on the list    
         if there is no transfer to do, the reserve waiting
         patron can pick it up                                    P =0, F=W,    I=filled 
         if there is a transfer to do, write in branchtransfer    P =0, F=T,    I=filled
           The pickup library recieve the book, it check in       P =0, F=W,    I=filled
  The patron borrow the book                                      P =0, F=F,    I=filled
  
  ==== 2nd use case ====
  patron requests a document, a given item,
    If pickup is holding branch                                   P =0, F=W,    I=filled
    If transfer needed, write in branchtransfer                   P =0, F=T,    I=filled
        The pickup library receive the book, it checks it in      P =0, F=W,    I=filled
  The patron borrow the book                                      P =0, F=F,    I=filled
  
=head1 FUNCTIONS

=over 2

=cut

BEGIN {
    # set the version for version checking
    $VERSION = 3.01;
	require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        &AddReserve
  
        &GetReservesFromItemnumber
        &GetReservesFromBiblionumber
        &GetReservesFromBorrowernumber
        &GetOldReservesFromBorrowernumber
        &ModOldReservesDisplay
        &GetReservesForBranch
        &GetReservesToBranch
        &GetReserveCount
        &GetReserveFee
        &GetReserveInfo
    
        &GetOtherReserves
        
        &ModReserveFill
        &ModReserveAffect
        &ModReserve
        &ModReserveStatus
        &ModReserveCancelAll
        &ModReserveMinusPriority
        
        &CheckReserves
        &CancelReserve
        &CancelReserves

        &SuspendReserve
        &ResumeReserve
        &GetSuspendedReservesFromBiblionumber
        &GetSuspendedReservesFromBorrowernumber
        &ResumeSuspendedReservesWithResumeDate
        
        &IsAvailableForItemLevelRequest
        
        &CanHoldMultipleItems
        &BorrowerHasReserve
    );
}

# not exported.
# sanity checks for running build_holds_queue.pl
sub CleanupQueue
{
   my $dbh = C4::Context->dbh;

   ## if reserve has been checked in at holdingbranch,
   ## remove it from tmp_holdsqueue.
   my $sth = $dbh->prepare("
         SELECT tmp_holdsqueue.reservenumber
           FROM reserves,tmp_holdsqueue
          WHERE reserves.found IS NOT NULL
            AND reserves.found IN ('W', 'T')
            AND reserves.priority = 0
            AND reserves.reservenumber = tmp_holdsqueue.reservenumber
   ");
   $sth->execute();
   while(my $row = $sth->fetchrow_hashref()) {
      my $sth2 = $dbh->prepare("
         DELETE FROM tmp_holdsqueue
          WHERE reservenumber = ?");
      $sth2->execute($$row{reservenumber});
   }

   ## race condition: pickup branch changed after previous run of
   ## build_holds_queue.pl.  Force sync data.
   $sth = $dbh->prepare('
      SELECT reserves.branchcode,tmp_holdsqueue.reservenumber
        FROM reserves,tmp_holdsqueue
       WHERE reserves.branchcode   != tmp_holdsqueue.pickbranch
         AND reserves.reservenumber = tmp_holdsqueue.reservenumber
   ');
   $sth->execute();
   while(my $row = $sth->fetchrow_hashref()) {
      my $sth2 = $dbh->prepare('
         UPDATE tmp_holdsqueue
            SET pickbranch    = ?
          WHERE reservenumber = ?');
      $sth2->execute($$row{branchcode},$$row{reservenumber});
   }

   ## rare condition: priorities collapsed for same borrower with
   ## multiple bib-level holds on same bib
   $sth = $dbh->prepare('
      SELECT count(*),reservenumber,biblionumber,borrowernumber,priority
        FROM reserves
       WHERE priority > 0
         AND found IS NULL
    GROUP BY borrowernumber,biblionumber,priority
      HAVING count(*)>1
         AND MIN(priority)
   ');
   $sth->execute();
   while(my $r = $sth->fetchrow_hashref()) {
      _NormalizePriorities($$r{biblionumber});
   }
   return 1;
}

sub SaveHoldInQueue
{
   my %new = @_;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare(sprintf("
         INSERT INTO tmp_holdsqueue(%s) VALUES(%s)",
         join(',',keys %new),
         join(',',map{'?'}keys %new)
      )
   ) || die $dbh->errstr();
   $sth->execute(values %new) || die $dbh->errstr();
   return 1;
}

sub DupecheckQueue
{
   my $reservenumber = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("
      SELECT 1
        FROM tmp_holdsqueue
       WHERE reservenumber = ?");
   $sth->execute($reservenumber);
   return ($sth->fetchrow_array)[0] // 0;
}

sub _getBranchesQueueWeight
{
   my $dbh = C4::Context->dbh;
   my $sth;
   my $dorand   = C4::Context->preference('RandomizeHoldsQueueWeight')   // 0;
   my $staylibs = C4::Context->preference('StaticHoldsQueueWeight')      // '';
   my $nextlibs = C4::Context->preference('NextLibraryHoldsQueueWeight') // '';
   my @staylibs = split(/\,\s*/,$staylibs);
   my @nextlibs = split(/\,\s*/,$nextlibs);
   my @branches = ();

   if (@nextlibs) {
      @branches = @nextlibs; undef @nextlibs;
   }
   elsif ($dorand) {
      if (@staylibs) { 
         use List::Util 'shuffle';
         @branches = shuffle(@staylibs);
      }
      else {
         $sth = $dbh->prepare('SELECT branchcode FROM branches ORDER BY RAND()');
         $sth->execute();
         while(my $row=$sth->fetchrow_hashref()) { push @branches, $$row{branchcode} }
      }
   }
   elsif (@staylibs) {
      @branches = @staylibs;
   }
   else {
      $sth = $dbh->prepare('SELECT branchcode FROM branches');
      $sth->execute();
      while(my $row=$sth->fetchrow_hashref()) { push @branches, $$row{branchcode} }
   }
   return @branches;
}

sub GetItemForBibPrefill
{
   my $res = shift;
   my $dbh = C4::Context->dbh;

   ## other item-level requests upon this bib are excluded from 
   ## eligible items for this bib
   my $sth = $dbh->prepare("SELECT itemnumber
      FROM reserves
     WHERE biblionumber = ?
       AND priority > 0  /* is in the queue */
       AND found IS NULL /* has not been filled/waiting/in transit */
       AND reservedate <= NOW()
       AND reservenumber != ?
       AND itemnumber IS NOT NULL") || die $dbh->errstr();
   $sth->execute($$res{biblionumber},$$res{reservenumber});
   my @notitems = $sth->fetchrow_array();
   $sth->finish();

   my @vals       = ($$res{biblionumber});
   my @branches   = _getBranchesQueueWeight();
   my $starti     = 0;
   my $idx        = 0;

   if (!!$$res{_pass}) {
      IDX:
      for my $i(0..$#branches) {
         if ($branches[$i] ~~ $$res{holdingbranch}) {
            $idx = $i;
            $starti = 1;
            last IDX;
         }
      }
   }
   else {
      $idx = 0;
      IDX:
      for my $i(0..$#branches) {
         if ($$res{pickbranch} ~~ $branches[$i]) {
            $idx = $i;
            last IDX;
         }
      }
   }
   my @lob   = splice(@branches,$idx);
   @branches = (@lob,@branches);
  
   my $sql = sprintf("
      SELECT biblio.title,
             items.itemnumber,
             items.biblionumber,
             items.itemcallnumber,
             items.barcode,
             items.holdingbranch,
             items.notforloan
        FROM items,biblio
       WHERE items.biblionumber = ? %s
         AND items.biblionumber = biblio.biblionumber",
      @notitems? sprintf("AND items.itemnumber NOT IN (%s)", 
         join(',',map{'?'}@notitems)) : ''
   );
   $sth = $dbh->prepare($sql) || die $dbh->errstr();
   $sth->execute($$res{biblionumber},@notitems);
   my @all = ();
   while(my $row = $sth->fetchrow_hashref()) { push @all, $row }
   $sth->finish();
   return unless @all;

   my $item; # leave void
   BRANCHITEM:
   for my $i($starti..$#branches) {
      foreach(@all) {
         if ($$_{holdingbranch} ~~ $branches[$i]) {
            $$_{found}            = $$res{found};
            $$_{borrowerbranch}   = $$res{borrowerbranch};
            $$_{borrowercategory} = $$res{categorycode};
            $$_{reservenumber}    = $$res{reservenumber};
            $item = _itemfillbib($_);
            last BRANCHITEM if $item;
         }
      }
   }

   if (!$item && $$res{_pass}) { ## back to the beginning
      $$item{_wraparound} = 1;   ## this flag only updates queue_sofar
   }
   return $item;
}

sub GetItemForQueue
{
   my $res = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("
      SELECT biblio.title,
             items.itemnumber,
             items.biblionumber,
             items.itemcallnumber,
             items.barcode,
             items.holdingbranch,
             items.notforloan
        FROM items,biblio
       WHERE biblio.biblionumber = items.biblionumber
         AND items.biblionumber = ?
         AND items.itemnumber   = ?") || die $dbh->errstr();
   $sth->execute($$res{biblionumber},$$res{itemnumber});
   my $item = $sth->fetchrow_hashref();
   return unless $item;
   $$item{found}            = $$res{found};
   $$item{borrowercategory} = $$res{borrowercategory};
   $$item{borrowerbranch}   = $$res{borrowerbranch};
   $$item{reservenumber}    = $$res{reservenumber};
   return _itemfillbib($item);
}


sub _itemfillbib
{
   my $item = shift;
   my $dbh = C4::Context->dbh;
   my $sth;

   ## trivial case: if item is currently checked out, it can't be used
   ## to fill a hold.  this is an explicit check not caught by
   ## IsAvailableForItemLevelRequest().
   return if $$item{onloan};

   ## theoretically, the above check should sync with the issues table,
   ## so skip that check.

   ## if the item can't be used to place a hold, it can't be used to
   ## fill a hold.
   return unless IsAvailableForItemLevelRequest($$item{itemnumber});

   ## notforloan: even if you can place a hold on a notforloan item,
   ## there's no real item avaiable to fill the hold
   return if $$item{notforloan} != 0;

   ## check with issuing rules
   $sth = $dbh->prepare("
      SELECT biblioitems.itemtype
        FROM biblioitems,items
       WHERE biblioitems.biblionumber = ?
         AND items.biblioitemnumber = biblioitems.biblioitemnumber
         AND items.itemnumber = ?");
   $sth->execute($$item{biblionumber},$$item{itemnumber});
   $$item{itemtype} = ($sth->fetchrow_array)[0];
   my $ir = C4::Circulation::GetIssuingRule(
      $$item{borrowercategory},
      $$item{itemtype},
      $$item{holdingbranch},
   );
   
   ## unfortunately, itemtype is not always set, so $ir could be undef
   if (exists $$ir{holdallowed}) {
      return if !$$ir{holdallowed};
      return if ( ($$ir{holdallowed} == 1) 
               && ($$item{holdingbranch} ne $$item{borrowerbranch}) );
   }

   ## is this item already waiting or in transit for somebody else?
   $sth = $dbh->prepare("SELECT 1 FROM reserves
     WHERE itemnumber = ?
       AND reservenumber != ?
       AND found IN ('W','T')");
   $sth->execute($$item{itemnumber},$$item{reservenumber});
   return if ($sth->fetchrow_array)[0];

   return $item;
}

# this deletes cancelled holds from the Holds Queue
sub UnorphanCancelledHolds
{
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT tmp_holdsqueue.reservenumber FROM reserves
      RIGHT JOIN tmp_holdsqueue ON reserves.reservenumber = tmp_holdsqueue.reservenumber
      WHERE reserves.reservenumber IS NULL");
   $sth->execute();
   while(my $row = $sth->fetchrow_hashref()) {
      my $sth2 = $dbh->prepare("DELETE FROM tmp_holdsqueue WHERE reservenumber = ?");
      $sth2->execute($$row{reservenumber});
   }
}

sub GetReservesForQueue 
{
    my $dbh = C4::Context->dbh;
    my $all = $dbh->selectall_hashref(q{
      SELECT reserves.reservenumber,
             reserves.biblionumber,
             reserves.itemnumber,
             borrowers.branchcode as borrowerbranch,
             borrowers.surname,
             borrowers.firstname,
             borrowers.phone,
             reserves.borrowernumber,
             borrowers.cardnumber,
             borrowers.categorycode,
             reserves.reservedate,
             reserves.branchcode as pickbranch,
             reserves.reservenotes as notes,
             reserves.priority,
             reserves.found
        FROM reserves,borrowers
       WHERE
         ( /* in transit or otherwise not waiting at pickup branch */
           (reserves.found IS NULL AND reserves.priority >= 1)
           OR (reserves.found = 'T' AND reserves.priority = 0)
         )
         AND reserves.reservedate <= NOW()
         AND reserves.borrowernumber = borrowers.borrowernumber
    /* this was added for the case of suspended reserves with high (low number) priority */
    GROUP BY reserves.biblionumber 
      HAVING MIN(priority)
    },'biblionumber');

    return $all;
}

sub GetHoldsQueueItems 
{
	my %g = @_;
   $g{branch} ||= $g{branchlimit} || ''; # allow synonymn
	my $dbh = C4::Context->dbh;
   my $sth;
   my $sql  = 'SELECT COUNT(*) FROM tmp_holdsqueue ';
   my @vals = ();
   if (!!$g{branch}) {
      $sql .= "WHERE holdingbranch = ?";
      push @vals, $g{branch};
   }
   $sth = $dbh->prepare($sql);
   $sth->execute(@vals);
   my $total = ($sth->fetchrow_array)[0];

   my @bind_params = ();
	my $query = q|SELECT 
         tmp_holdsqueue.*, 
         biblio.author, 
         items.ccode, 
         items.location, 
         items.enumchron, 
         items.cn_sort, 
         items.copynumber,
         biblioitems.publishercode,
         biblio.copyrightdate,
         biblioitems.publicationyear,
         biblioitems.pages,
         biblioitems.size,
         biblioitems.publicationyear,
         biblioitems.isbn
    FROM tmp_holdsqueue
         JOIN biblio      USING (biblionumber)
    LEFT JOIN biblioitems USING (biblionumber)
    LEFT JOIN items       USING (  itemnumber)
   |;
   if ($g{branch}) {
	   $query .="WHERE tmp_holdsqueue.holdingbranch = ? ";
      push @bind_params, $g{branch};
   }
   $g{orderby} ||= 'tmp_holdsqueue.reservedate';
   $query .= " ORDER BY $g{orderby}";
   if ($g{limit}) {
      $g{offset} ||= 0;
      $query .= " LIMIT $g{offset},$g{limit} ";
   }
	$sth = $dbh->prepare($query);
	$sth->execute(@bind_params);
	my $items = [];
   my $userenv = C4::Context->userenv;
   while (my $row = $sth->fetchrow_hashref){
      $$row{fillable} = $$userenv{branch} ~~ $$row{holdingbranch} ?1:0;
      my $sth2 = $dbh->prepare('SELECT found FROM reserves WHERE reservenumber = ?');
      $sth2->execute($$row{reservenumber});
      $$row{found}           = ($sth2->fetchrow_array)[0];
      $$row{found_waiting}   = 1 if $$row{found} ~~ 'W';
      $$row{found_intransit} = 1 if $$row{found} ~~ 'T';
      $$row{reservedate}     = C4::Dates::format_date($$row{reservedate});
      push @$items, $row;
   }
   return $total,$items;
}

=item AddReserve
    
    AddReserve($branch,$borrowernumber,$biblionumber,$constraint,
    $bibitems,$priority,$notes,$title,$checkitem,$found)

=cut

sub AddReserve {
    my (
        $branch,    $borrowernumber, $biblionumber,
        $constraint, $bibitems,  $priority, $resdate,  $notes,
        $title,      $checkitem, $found
    ) = @_;
    my $dbh     = C4::Context->dbh;
    my $const   = lc substr( $constraint, 0, 1 );

    my ($sec,$min,$hour,$day,$mon,$year,undef,undef,undef) = localtime();
    my $timestamp = sprintf '%04d-%02d-%02d %02d:%02d:%02d', 1900+$year, 1+$mon, $day, $hour, $min, $sec;
    $resdate = ($resdate) ? format_date_in_iso($resdate) : $timestamp;

    if ( C4::Context->preference( 'AllowHoldDateInFuture' ) ) {
	# Make room in reserves for this before those of a later reserve date
	$priority = _ShiftPriorityByDateAndPriority( $biblionumber, $resdate, $priority );
    }

    my $waitingdate;
    # If the reserv had the waiting status, we had the value of the resdate
    if ( $found ~~ 'W' ) {
        $waitingdate = $resdate;
    }

    my $expDays = C4::Context->preference('HoldExpireLength');
    my $expirationdate = '';
    if ($expDays) {
       $expirationdate = "DATE_ADD(NOW(),INTERVAL $expDays DAY)";
    }
    else {
       $expirationdate = 'NULL';
    }

    # updates take place here
    my $query = qq/
        INSERT INTO reserves
            (borrowernumber,biblionumber,reservedate,branchcode,constrainttype,
            priority,reservenotes,itemnumber,found,waitingdate,expirationdate)
        VALUES
             (?,?,?,?,?,
             ?,?,?,?,?,$expirationdate)
    /;
    my $sth = $dbh->prepare($query);
    $sth->execute(
        $borrowernumber, $biblionumber, $resdate, $branch,
        $const,          $priority,     $notes,   $checkitem,
        $found,          $waitingdate
    );
    my $new_reservenumber = $dbh->last_insert_id(undef, undef, undef, undef);

    # Assign holds fee if applicable
    my $fee =
      GetReserveFee( $borrowernumber, $biblionumber, $constraint, $bibitems );
    if ( $fee > 0 ) {
        my $nextacctno = &getnextacctno( $borrowernumber );
        my $query      = qq/
        INSERT INTO accountlines
            (borrowernumber,accountno,date,amount,description,accounttype,amountoutstanding)
        VALUES
            (?,?,now(),?,?,'Res',?)
    /;
        my $usth = $dbh->prepare($query);
        $usth->execute( $borrowernumber, $nextacctno, $fee,
            "Reserve Charge - $title", $fee );

    }

    UpdateStats(
      $branch,
      my $type = 'reserve',
      my $amount,
      my $other = $biblionumber,
      my $itemnum,
      my $itemtype,
      $borrowernumber,
      my $accountno
    );

    return $new_reservenumber;
}

=item GetReservesFromBiblionumber

($count, $title_reserves) = &GetReserves($biblionumber);

This function gets the list of reservations for one C<$biblionumber>, returning a count
of the reserves and an arrayref pointing to the reserves for C<$biblionumber>.

=cut

sub GetReservesFromBiblionumber {
    my ($biblionumber) = shift or return (0, []);
    my ($all_dates) = shift;
    my ($bib_level_only) = shift;
    my $dbh   = C4::Context->dbh;

    # Find the desired items in the reserves
    my $query = "
        SELECT  reserves.reservenumber,
                reserves.branchcode,
                reserves.timestamp AS rtimestamp,
                reserves.priority,
                reserves.biblionumber,
                reserves.borrowernumber,
                reserves.reservedate,
                reserves.constrainttype,
                reserves.found,
                reserves.itemnumber,
                reserves.reservenotes,
                reserves.waitingdate,
                biblioitems.itemtype
        FROM     reserves
        LEFT JOIN biblioitems ON biblioitems.biblionumber = reserves.biblionumber
        WHERE reserves.biblionumber = ? ";
    unless ( $all_dates ) {
        $query .= "AND reservedate <= NOW() ";
    }
    if ( $bib_level_only ) {
        $query .= "AND reserves.itemnumber IS NULL ";
    }
    $query .= "ORDER BY reserves.priority";

    my $reserves = $dbh->selectall_arrayref($query, {Slice => {}}, $biblionumber);
    return (scalar @$reserves, $reserves);
}

sub GetSuspendedReservesFromBiblionumber {
    my ( $biblionumber ) = @_;
    my $dbh   = C4::Context->dbh;

    # Find the desired items in the reserves
    my $query = q{
        SELECT *
        FROM  reserves, borrowers
        WHERE biblionumber = ?
          AND reserves.found = 'S'
          AND borrowers.borrowernumber = reserves.borrowernumber
        ORDER BY priority
    };
    my $reserves = $dbh->selectall_arrayref($query, {Slice => {}}, $biblionumber);
    return (scalar @$reserves, $reserves);
}

=item GetReservesFromItemnumber

 ( $reservenumber, $reservedate, $borrowernumber, $branchcode ) = GetReservesFromItemnumber($itemnumber);

   TODO :: Description here

=cut

sub GetReservesFromItemnumber {
    my ( $itemnumber, $all_dates ) = @_;

    my $query = q{
    SELECT reservenumber,reservedate,borrowernumber,branchcode
    FROM   reserves
    WHERE  itemnumber=?
      AND  (found <> 'S' OR found IS NULL)
    };
    unless ( $all_dates ) {
	   $query .= ' AND reservedate <= NOW()';
    }
    $query .= ' ORDER BY priority ASC LIMIT 1';

    return C4::Context->dbh->selectrow_array($query, undef, $itemnumber);
}

=item GetReservesFromBorrowernumber

    $borrowerreserv = GetReservesFromBorrowernumber($borrowernumber,$status);
    
    TODO :: Description
    
=cut

sub GetReservesFromBorrowernumber {
    my ( $borrowernumber, $status ) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;
    if ($status ~~ 'W') {
        $sth = $dbh->prepare("
            SELECT *
            FROM   reserves
            WHERE  borrowernumber=?
                AND found =?
            ORDER BY reservedate
        ");
        $sth->execute($borrowernumber,$status);
    } elsif ($status ~~ 'U') {
        $sth = $dbh->prepare("
            SELECT *
            FROM   reserves
            WHERE  borrowernumber=?
                AND (found IS NULL OR found = 'T')
            ORDER BY reservedate
        ");
        $sth->execute($borrowernumber);
    } else {
        $sth = $dbh->prepare("
            SELECT *
            FROM   reserves
            WHERE  borrowernumber=?
            ORDER BY reservedate
        ");
        $sth->execute($borrowernumber);
    }
    my $data = $sth->fetchall_arrayref({});
    return @$data;
}

=item GetOldReservesFromBorrowernumber

    $borroweroldreserv = GetOldReservesFromBorrowernumber($borrowernumber,$type);

    where $type = 'cancellation|expiration|fill';

    TODO :: Description

=cut

sub GetOldReservesFromBorrowernumber {
    my ( $borrowernumber, $type, $user) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;
    my $num_days;
    if ($type ~~ 'expiration') {
        $num_days = ($user ~~ 'opac') ?
           C4::Context->preference('OPACShowExpiredHolds') :
           C4::Context->preference('StaffShowExpiredHolds');
        $num_days //= 10000;
        $sth = $dbh->prepare("
            SELECT *
            FROM   old_reserves
            WHERE  borrowernumber=?
                AND cancellationdate IS NULL
                AND (found IS NULL OR found <> 'F')
                AND (DATEDIFF(CURDATE(),expirationdate) < $num_days)
            ORDER BY expirationdate DESC
        ");
        $sth->execute($borrowernumber);
    } elsif ($type ~~ 'cancellation') {
        $num_days = ($user ~~ 'opac') ?
           C4::Context->preference('OPACShowCancelledHolds') :
           C4::Context->preference('StaffShowCancelledHolds');
        $num_days //= 10000;
        $sth = $dbh->prepare("
            SELECT *
            FROM   old_reserves
            WHERE  borrowernumber=?
                AND cancellationdate IS NOT NULL
                AND (DATEDIFF(CURDATE(),cancellationdate) < $num_days)
            ORDER BY cancellationdate DESC
        ");
        $sth->execute($borrowernumber);
    } else { # filled
        $num_days = ($user ~~ 'opac') ?
           C4::Context->preference('OPACShowCompletedHolds') :
           C4::Context->preference('StaffShowCompletedHolds');
        $num_days //= 10000;
        $sth = $dbh->prepare("
            SELECT *
            FROM   old_reserves
            WHERE  borrowernumber=?
                AND found = 'F'
                AND (DATEDIFF(CURDATE(),DATE(timestamp)) < $num_days)
            ORDER BY timestamp DESC
        ");
        $sth->execute($borrowernumber);
    }
    my $data = $sth->fetchall_arrayref({});
    return @$data;
}

=item ModOldReservesDisplay

  ModOldReservesDisplay($reservenumber);

=cut

sub ModOldReservesDisplay {
    my ($reservenumber) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare("
        UPDATE old_reserves
        SET displayexpired = 0
        WHERE reservenumber = ?
    ");
    $sth->execute($reservenumber);
    return();
}

=item GetReservesByBorrowernumberAndItemtype

    $borrowerreserv = GetReservesByBorrowernumberAndItemtypeOf($borrowernumber, $biblionumber);
    
    TODO :: Descritpion
    
=cut

sub GetReservesByBorrowernumberAndItemtypeOf {
    my ( $borrowernumber, $biblionumber ) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;

    $sth = $dbh->prepare("SELECT itemtype FROM biblioitems WHERE biblionumber = ?");
    $sth->execute( $biblionumber );
    my $res = $sth->fetchrow_hashref();
    my $itemtype = $res->{'itemtype'};

    $sth = $dbh->prepare("
            SELECT *
            FROM   reserves, biblioitems
            WHERE  borrowernumber=?
            AND reserves.biblionumber = biblioitems.biblionumber
            AND biblioitems.itemtype = ?
            ORDER BY reservedate
    ");
    $sth->execute($borrowernumber,$itemtype);
    my $data = $sth->fetchall_arrayref({});
    return @$data;
}

#-------------------------------------------------------------------------------------
sub BorrowerHasReserve {
    my ( $borrowernumber, $biblionumber, $itemnumber ) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;
    
    if ( $biblionumber ) {
      $sth = $dbh->prepare("
            SELECT COUNT(*) AS hasReserve
            FROM   reserves
            WHERE  borrowernumber = ?
            AND    biblionumber = ?
            ORDER BY reservedate
        ");
      $sth->execute( $borrowernumber, $biblionumber );
    } elsif ( $itemnumber ) {
      $sth = $dbh->prepare("
            SELECT COUNT(*) AS hasReserve
            FROM   reserves
            WHERE  borrowernumber = ?
            AND    itemnumber = ?
            ORDER BY reservedate
        ");
      $sth->execute( $borrowernumber, $itemnumber );
    } else {
      return -1;
    }

    my $data = $sth->fetchrow_hashref();
    return $data->{'hasReserve'};
}

=item GetReservesFromBorrowernumber

    $suspended_reserves = GetSuspendedReservesFromBorrowernumber($borrowernumber);
    
=cut

sub GetSuspendedReservesFromBorrowernumber {
    my ( $borrowernumber ) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare("
        SELECT *
        FROM   reserves
        WHERE  borrowernumber=?
        AND found = 'S'
        ORDER BY reservedate
    ");
    $sth->execute($borrowernumber);
    my $data = $sth->fetchall_arrayref({});
    return @$data;
}

=item GetReserveCount

$number = &GetReserveCount($borrowernumber [, $today [, $shelf_holds_only]  ]);

this function returns the number of reservation for a borrower given on input arg.

If optional $today is true, will return only holds placed today.

If option $shelf_holds_only is true, will only return the count of holds placed on items not checked out.
=cut

sub GetReserveCount {
    my ($borrowernumber, $today, $shelf_holds_only ) = @_;

    my $dbh = C4::Context->dbh;

    my $query = "SELECT COUNT(*) AS counter FROM reserves WHERE borrowernumber = ?";
    
    if ( $today ) {
      $query .= ' AND DATE( reserves.timestamp ) = DATE( NOW() )';
    }

    if ( $shelf_holds_only ) {
      $debug and warn "GetReserveCount: Shelf Holds Only";
      $query = "
        SELECT COUNT( DISTINCT ( items.biblionumber ) ) AS counter
        FROM items
        LEFT JOIN issues ON issues.itemnumber = items.itemnumber
        LEFT JOIN reserves ON reserves.biblionumber = items.biblionumber
        WHERE issues.timestamp IS NULL
        AND reserves.biblionumber IS NOT NULL
        AND reserves.borrowernumber = ?
        AND DATE( reserves.timestamp ) = DATE( NOW( ) )
      ";
    }

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    my $row = $sth->fetchrow_hashref;

    my $res_count = $row->{counter};
    return $res_count;
}

=item GetOtherReserves

($messages,$nextreservinfo)=$GetOtherReserves(itemnumber);

Check queued list of this document and check if this document must be  transfered

=cut

sub GetOtherReserves {
    my ($itemnumber) = @_;
    $debug and warn "GetOtherReserves( $itemnumber )";
    my $messages;
    my $nextreservinfo;
    my ( undef, $checkreserves ) = CheckReserves($itemnumber);
    if ($checkreserves) {
        my $iteminfo = GetItem($itemnumber);
        if ( $iteminfo->{'holdingbranch'} ne $checkreserves->{'branchcode'} ) {
            $messages->{'transfert'} = $checkreserves->{'branchcode'};
            #minus priorities of others reservs
            ModReserveMinusPriority(
                $itemnumber,
                $checkreserves->{'borrowernumber'},
                $iteminfo->{'biblionumber'},
                $checkreserves->{'reservenumber'}
            );

            #launch the subroutine dotransfer
            C4::Items::ModItemTransfer(
                $itemnumber,
                $iteminfo->{'holdingbranch'},
                $checkreserves->{'branchcode'},
              ),
              ;
        }

     #step 2b : case of a reservation on the same branch, set the waiting status
        else {
            $messages->{'waiting'} = 1;
            ModReserveMinusPriority(
                $itemnumber,
                $checkreserves->{'borrowernumber'},
                $iteminfo->{'biblionumber'},
                $checkreserves->{'reservenumber'}                
            );
            ModReserveStatus($itemnumber,'W',$checkreserves->{'reservenumber'});
        }

        $nextreservinfo = $checkreserves->{'borrowernumber'};
    }

    return ( $messages, $nextreservinfo );
}

=item GetReserveFee

$fee = GetReserveFee($borrowernumber,$biblionumber,$constraint,$biblionumber);

Calculate the fee for a reserve

=cut

sub GetReserveFee {
    my ($borrowernumber, $biblionumber, $constraint, $bibitems ) = @_;

    #check for issues;
    my $dbh   = C4::Context->dbh;
    my $const = lc substr( $constraint, 0, 1 );
    my $query = qq/
      SELECT * FROM borrowers
    LEFT JOIN categories ON borrowers.categorycode = categories.categorycode
    WHERE borrowernumber = ?
    /;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    my $data = $sth->fetchrow_hashref;
    $sth->finish();
    my $fee = $data->{'reservefee'} // 0;
    $query = qq/
      SELECT * FROM items
    LEFT JOIN itemtypes ON items.itype = itemtypes.itemtype
    WHERE biblionumber = ?
    /;
    my $isth = $dbh->prepare($query);
    $isth->execute($biblionumber);
    my $idata = $isth->fetchrow_hashref // {};
    $$idata{reservefee} //= 0;
    $fee += $idata->{'reservefee'};

    if ( $fee > 0 ) {

        # check for items on issue
        # first find biblioitem records
        my @biblioitems;
        my $sth1 = $dbh->prepare(
            "SELECT * FROM biblio LEFT JOIN biblioitems on biblio.biblionumber = biblioitems.biblionumber
                   WHERE (biblio.biblionumber = ?)"
        );
        $sth1->execute($biblionumber);
        while ( my $data1 = $sth1->fetchrow_hashref ) {
            if ( $const ~~ 'a' ) {
                push @biblioitems, $data1;
            }
            else {
                my $found = 0;
                foreach my $bibitemnum (@$bibitems) {
                    if ($bibitemnum == $data->{biblioitemnumber}) {
                        $found = 1;
                        last;
                    }
                }
                if ( ($const ~~ 'o' && $found) || !$found ) {
                    push @biblioitems, $data1;
                }
            }
        }
        $sth1->finish;
        my $cntitemsfound = @biblioitems;
        my $issues        = 0;
        my $x             = 0;
        my $allissued     = 1;
        while ( $x < $cntitemsfound ) {
            my $bitdata = $biblioitems[$x];
            my $sth2    = $dbh->prepare(
                "SELECT * FROM items
                     WHERE biblioitemnumber = ?"
            );
            $sth2->execute( $bitdata->{'biblioitemnumber'} );
            while ( my $itdata = $sth2->fetchrow_hashref ) {
                my $sth3 = $dbh->prepare(
                    "SELECT * FROM issues
                       WHERE itemnumber = ?"
                );
                $sth3->execute( $itdata->{'itemnumber'} );
                if ( my $isdata = $sth3->fetchrow_hashref ) {
                }
                else {
                    $allissued = 0;
                }
            }
            $x++;
        }
        if ( $allissued == 0 ) {
            my $rsth =
              $dbh->prepare("SELECT * FROM reserves WHERE biblionumber = ?");
            $rsth->execute($biblionumber);
            if ( my $rdata = $rsth->fetchrow_hashref ) {
            }
            else {
                $fee = 0;
            }
        }
    }
    return $fee;
}

=item GetReservesToBranch

@transreserv = GetReservesToBranch( $frombranch );

Get reserve list for a given branch

=cut

sub GetReservesToBranch {
    my ( $frombranch ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "SELECT borrowernumber,reservedate,itemnumber,timestamp
         FROM reserves 
         WHERE priority='0' 
           AND branchcode=?"
    );
    $sth->execute( $frombranch );
    my @transreserv;
    my $i = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        $transreserv[$i] = $data;
        $i++;
    }
    return (@transreserv);
}

=item GetReservesForBranch

@transreserv = GetReservesForBranch($frombranch);

=cut

sub GetReservesForBranch {
    my ($frombranch) = @_;
    my $dbh          = C4::Context->dbh;
	my $query        = "SELECT borrowernumber,reservedate,itemnumber,waitingdate,reservenumber
        FROM   reserves 
        WHERE   priority='0'
            AND found='W' ";
    if ($frombranch){
        $query .= " AND branchcode=? ";
	}
    $query .= "ORDER BY waitingdate" ;
    my $sth = $dbh->prepare($query);
    if ($frombranch){
		$sth->execute($frombranch);
	}
    else {
		$sth->execute();
	}
    my @transreserv;
    my $i = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        $transreserv[$i] = $data;
        $i++;
    }
    return (@transreserv);
}

=item CheckReserves

  ($status, $reserve) = &CheckReserves($itemnumber);

Find a book in the reserves.

C<$itemnumber> is the book's item number.

As I understand it, C<&CheckReserves> looks for the given item in the
reserves. If it is found, that's a match, and C<$status> is set to
C<Waiting>.

Otherwise, it finds the most important item in the reserves with the
same biblio number as this book (I'm not clear on this) and returns it
with C<$status> set to C<Reserved>.

C<&CheckReserves> returns a two-element list:

C<$status> is either C<Waiting>, C<Reserved> (see above), or 0.

C<$reserve> is the reserve item that matched. It is a
reference-to-hash whose keys are mostly the fields of the reserves
table in the Koha database.

=cut

sub CheckReserves {
    my $itemnumber = shift;

    # Split this out to make testing a bit easier
    return _GetNextReserve($itemnumber, _Findgroupreserve($itemnumber));
}

sub _GetNextReserve {
    my ($itemnumber, $reserves) = @_;

    return (0, 0) if !defined $reserves;

    my $item = C4::Items::GetItem($itemnumber);

    # $highest is used to track the most important item
    # in the list returned by &_Findgroupreserve. (The lower priority,
    # the more important the item.)
    my $highest;
    my $exact;
    my $nohold = 0;

    foreach my $res (@$reserves) {
        $res->{dbitemnumber} = $res->{itemnumber};
        $res->{itemnumber} = $itemnumber; # Some callers require this be set
        my $borrower = C4::Members::GetMember($res->{borrowernumber});
        my $branch = C4::Circulation::_GetCircControlBranch($item, $borrower);
        my $issuingrule
            = C4::Circulation::GetIssuingRule($res->{borrowercategory}, $item->{itype}, $branch);
        next unless ($issuingrule);

        if (!$issuingrule->{holdallowed}) {
            $nohold++;
            next;
        }
        if ($res->{priority} == 0
            && ($res->{found} ~~ 'T' || $res->{found} ~~ 'W') ) {
            # Found it
            $exact = $res;
            last;
        }
        if (!defined $highest || $res->{priority} < $highest->{priority}) {
            # See if this item is more important than what we've got so far.
            $highest = $res;
        }
    }
    return ('Waiting', $exact) if $exact;
    return (0, 0) if ($nohold == @$reserves);

    # If constraints about preferring local reserves are satisfied, reassign to highest
    if (C4::Context->preference('FillRequestsAtPickupLibrary')
        && (@$reserves > C4::Context->preference('HoldsTransportationReductionThreshold')
            || C4::Context->preference('HoldsTransportationReductionThreshold') ~~ 0)
        ) {
        my $local  = _NextLocalReserve($reserves);

        if ($local && $local->{reservenumber} != $highest->{reservenumber}) {
            my $highest_dt = DateTime::Format::DateParse->parse_datetime($highest->{reservedate});
            my $local_dt = DateTime::Format::DateParse->parse_datetime($local->{reservedate});
            my $age_in_days = $highest_dt->delta_days($local_dt)->delta_days;

            if ($age_in_days < C4::Context->preference('FillRequestsAtPickupLibraryAge')) {
                $highest = $local;
            }
        }
    }

    return ('Reserved', $highest);
}

=item _NextLocalReserve

  my $reserve = _NextLocalReserve( \@reserves );
  
  Returns the highest priority reserve for the given list
  (from _Findgroupreserve) whose pickup location is the logged in branch, if any.
=cut

sub _NextLocalReserve {
    my $reserves = shift;

    my $branchcode = (C4::Context->userenv) ? C4::Context->userenv->{branch} : '';
    my @pruned = grep {$_->{branchcode} ~~ $branchcode} @$reserves;
    my @sorted = sort {$a->{priority} <=> $b->{priority}} @pruned;

    return $sorted[0];
}

## not exported.
## flag a list of a cancelled holds as being off the holds shelf
## by setting priority = -1
sub UnshelfLapsed
{
   my @reservenumbers = @_;
   return 0 unless @reservenumbers;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare(sprintf('UPDATE old_reserves SET priority=-1 WHERE reservenumber IN(%s)',
         join(',', map{'?'} @reservenumbers)
      )
   );
   my $fx = $sth->execute(@reservenumbers);
   return $fx;
}

=item CancelReserves
  &CancelReserves({
    [ biblionumber => $biblionumber, ]
    [ itemnumber => $itemnumber, ]
  });
  
  Cancels all the reserves for the given itemnumber
  or biblionumber. If both are supllied, all the reserves
  for the given biblio are deleted, as the reserves for
  the given itemnumber would be included.
  
=cut

sub CancelReserves {
    my ( $params ) = @_;
    my $biblionumber = $params->{'biblionumber'};
    my $itemnumber   = $params->{'itemnumber'};
    
    my $dbh = C4::Context->dbh;
    
    return unless $biblionumber || $itemnumber;

    my @sql_params;

    my $sql = "SELECT reservenumber, biblionumber FROM reserves WHERE ";
    if ( $itemnumber ) {
      $sql .= " itemnumber = ? ";
      push( @sql_params, $itemnumber );
    } else {
      $sql .= " biblionumber = ?";
      push( @sql_params, $biblionumber );
    }
    
    my $sth = $dbh->prepare( $sql );
    $sth->execute( @sql_params );
    
    while ( my $reserve = $sth->fetchrow_hashref() ) {
      CancelReserve( $reserve->{'reservenumber'}, $reserve->{'biblionumber'} );
    }
}

sub _moveToOldReserves {
    my $reservenumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth;
    my $query;

    ## dupecheck for development
    $sth = $dbh->prepare('DELETE FROM old_reserves WHERE reservenumber=?');
    $sth->execute($reservenumber);

    $query = "INSERT INTO old_reserves SELECT * FROM reserves WHERE reservenumber = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($reservenumber) or
        croak sprintf "Cannot transfer reserve '%d': %s\n", $reservenumber//-1, $dbh->errstr;

    $query = "DELETE FROM reserves WHERE reservenumber = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($reservenumber) or
        croak sprintf "Cannot delete reserve '%d': %s\n", $reservenumber//-1, $dbh->errstr;
}

=item CancelReserve

  &CancelReserve( $reservenumber );

Cancels a reserve.

C<$reservenumber> is the unique key for the reserve to be canceled.

C<&CancelReserve> also adjusts the priorities of the other people
who are waiting on the book.

=cut

sub CancelReserve {
    my ( $reservenumber ) = @_;
    my $dbh = C4::Context->dbh;

    my $reserve = GetReserve($reservenumber);
    croak "Unable to find reserve ($reservenumber)" if !$reserve;

    $dbh->do(q{
        UPDATE reserves
        SET    cancellationdate = now(),
               priority         = 0
        WHERE  reservenumber    = ?
    }, undef, $reservenumber);

    _moveToOldReserves($reservenumber);
    _NormalizePriorities($reserve->{biblionumber});

    $dbh->do('DELETE FROM tmp_holdsqueue WHERE reservenumber = ?', undef, $reservenumber);

    my $moduser    = C4::Context->userenv->{number};
    my $branchcode = C4::Context->userenv->{branch};
    UpdateReserveCancelledStats(
      $branchcode, 'reserve_canceled', undef, $reserve->{biblionumber},
      $reserve->{itemnumber}, undef, $reserve->{borrowernumber},
      undef, $moduser
    );

    _sendReserveCancellationLetter($reserve);
}

sub _sendReserveCancellationLetter {
    my $reserve = shift;

    # Pull borrowernumber of the user performing the action for logging
    my $moduser    = C4::Context->userenv->{number};
    my $branchcode = C4::Context->userenv->{branch};
    
    # Send cancellation notice, if desired
    my $mprefs = C4::Members::Messaging::GetMessagingPreferences( { 
      borrowernumber => $reserve->{borrowernumber},
      message_name   => 'Hold Cancelled'
    } );

    if ( $mprefs->{'transports'} && C4::Context->preference('EnableHoldCancelledNotice')) {
      my $borrower
          = C4::Members::GetMember( $reserve->{borrowernumber}, 'borrowernumber');
      my $biblio
          = GetBiblioData($reserve->{biblionumber})
          or die sprintf "BIBLIONUMBER: %d\n", $reserve->{biblionumber};
      my $letter = C4::Letters::getletter( 'reserves', 'HOLD_CANCELLED');
      my $admin_email_address = C4::Context->preference('KohaAdminEmailAddress');                

      C4::Letters::parseletter( $letter, 'branches', $reserve->{branchcode} );
      C4::Letters::parseletter( $letter, 'borrowers', $reserve->{borrowernumber} );
      C4::Letters::parseletter( $letter, 'biblio', $reserve->{biblionumber} );
      C4::Letters::parseletter( $letter, 'reserves', $reserve->{borrowernumber}, $reserve->{biblionumber} );
      C4::Letters::parseletter( $letter, 'items', $reserve->{itemnumber} );
        
      C4::Letters::EnqueueLetter(
        { letter                 => $letter,
          borrowernumber         => $borrower->{'borrowernumber'},
          message_transport_type => $mprefs->{'transports'}->[0],
          from_address           => $admin_email_address,
          to_address             => $borrower->{'email'},
        }
      );
    }
}

=item ModReserve

=over 4

ModReserve($rank, $biblio, $borrower, $branch[, $itemnumber])

=back

Change a hold request's priority or cancel it.

C<$rank> specifies the effect of the change.  If C<$rank>
is 'W' or 'n', nothing happens.  This corresponds to leaving a
request alone when changing its priority in the holds queue
for a bib.

If C<$rank> is 'del', the hold request is cancelled.

If C<$rank> is an integer greater than zero, the priority of
the request is set to that value.  Since priority != 0 means
that the item is not waiting on the hold shelf, setting the 
priority to a non-zero value also sets the request's found
status and waiting date to NULL. 

The optional C<$itemnumber> parameter is used only when
C<$rank> is a non-zero integer; if supplied, the itemnumber 
of the hold request is set accordingly; if omitted, the itemnumber
is cleared.

FIXME: Note that the forgoing can have the effect of causing
item-level hold requests to turn into title-level requests.  This
will be fixed once reserves has separate columns for requested
itemnumber and supplying itemnumber.

=cut

sub ModReserve {
    my ($priority, $biblionumber, $borrowernumber, $branchcode, $itemnumber, $reservenumber) = @_;

    return if $priority ~~ 'W';
    return if $priority ~~ 'n';

    if ( $priority ~~ 'del' ) {
        ModReserveCancelAll($reservenumber, $itemnumber);
    }
    elsif ($priority =~ /^\d+/ and $priority > 0) {
        my $query = q{
        UPDATE reserves
        SET    priority = ?,
               branchcode = ?,
               itemnumber = ?,
               found = NULL,
               waitingdate = NULL,
               expirationdate = NULL
        WHERE  reservenumber = ?
        };
        C4::Context->dbh->do(
            $query, undef, $priority, $branchcode, $itemnumber, $reservenumber);
        _FixPriority($reservenumber, $priority);
    }
    return;
}

sub ModReservePass
{
   my $res = shift;
   my $dbh = C4::Context->dbh;
   my $sth;

   ## normalize columns like GetReservesForQueue()
   $$res{notes}      = $$res{reservenotes}; delete($$res{reservenotes});
   $$res{pickbranch} = $$res{branchcode};   delete($$res{branchcode});
   $sth = $dbh->prepare("
      SELECT branchcode as borrowerbranch,
             surname,
             firstname,
             phone,
             borrowernumber,
             cardnumber,
             categorycode as borrowercategory
        FROM borrowers
       WHERE borrowernumber = ?");
   $sth->execute($$res{borrowernumber});
   my $row = $sth->fetchrow_hashref();
   foreach(keys %$row ) { $$res{$_} = $$row{$_} }

   ## get info from tmp_holdsqueue
   $sth = $dbh->prepare("
      SELECT queue_sofar,
             item_level_request,
             holdingbranch,
             itemnumber
        FROM tmp_holdsqueue
       WHERE reservenumber = ?");
   $sth->execute($$res{reservenumber});
   ($$res{queue_sofar},
    $$res{item_level_request},
    $$res{holdingbranch},
    $$res{itemnumber}) = $sth->fetchrow_array;

   ## sanity check: don't let UI layer do this for us.
   ## if this is an item_level_request, we cannot pass it
   if ($$res{item_level_request}) {
      return undef,'Item-level request';
   }

   ## for a bib-level request, pass it to the next library with an 
   ## available item.
   $$res{_pass} = 1;
   my $item = GetItemForBibPrefill($res);
   if ($$item{_wraparound}) {
      $$res{queue_sofar} .= ",$$res{holdingbranch}";
      $sth = $dbh->prepare('
      UPDATE tmp_holdsqueue
         SET queue_sofar   = ?
       WHERE reservenumber = ?');
      $sth->execute($$res{queue_sofar},$$res{reservenumber});
      return $$res{reservenumber};
   }
   return undef, 'Not available at other libraries' unless $$item{itemnumber};

   ## update tmp_holdsqueue's holdingbranch for itemnumber
   $$res{queue_sofar} .= ",$$item{holdingbranch}";
   $sth = $dbh->prepare('UPDATE tmp_holdsqueue
      SET itemnumber    = ?,
          barcode       = ?,
          holdingbranch = ?,
          queue_sofar   = ?
    WHERE reservenumber = ?');
   $sth->execute(
      $$item{itemnumber},
      $$item{barcode},
      $$item{holdingbranch},
      $$res{queue_sofar},
      $$res{reservenumber}
   );
   return $$item{itemnumber};
}

=item ModReserveFill

  &ModReserveFill($reserve);

Fill a reserve. If I understand this correctly, this means that the
reserved book has been found and given to the patron who reserved it.
That is, the barcode has been scanned it at checkin.

C<$reserve> specifies the reserve to fill. It is a reference-to-hash
whose keys are fields from the reserves table in the Koha database.

Returns true on success.

=cut

# not exported.
# upon checkout, set that the reserve is completed.
# overlying logic assumes item-level hold, however this can be true
# also of bib-level holds.
# $co* prefix is checkout
sub ModReserveFillCheckout
{
   my($coBorrowernumber,$coBiblionumber,$coItemnumber,$res) = @_; # the reserves hash should be complete
   my $dbh = C4::Context->dbh;
   my $sth;
   my $proceed = 0;
   my $currBranch = C4::Context->userenv->{branch};
   $res //= {};
   
   ## trivial: do nothing if there are no reserves
   return 1 unless $res;

   ## for whatever reason, this is the wrong bib.
   ## hold harmless and do nothing.
   return 1 if $coBiblionumber != $$res{biblionumber};

   ## patron who is checking out is not the one who placed the hold.
   ## ignore, do nothing.  If we get here, overrides were performed.
   return 1 if $coBorrowernumber != $$res{borrowernumber};

   ## item-level hold
   if ($$res{itemnumber}) {
      ## edge case
      if ($$res{itemnumber} != $coItemnumber) {
         die qq|Unexpected workflow: not the right item (checkout itemnumber=$coItemnumber)
            for item-level hold requested by this patron (reserve itemnumber=$$res{itemnumber})
         |;
         ## it is possible for patron to check out a different item of the same bib
         ## (see behavior of CheckReserves(\$itemnumber) called in Circulation::AddIssue(),
         ## in which case the above if() would never occur.
      }
      ## else patron is checking out item-level hold
   }
   ## else patron is checking out item for correct bib-level hold

   ## first of all, make sure we are checking out item at pickup branch
   if ($currBranch ne $$res{branchcode}) {
      die qq|Unexpected workflow: item probably needs checkin and transfer before checkout
         reserves.branchcode=$$res{branchcode}
         currBranch=$currBranch (*** HERE ***)
         checkout itemnumber=$coItemnumber
         reserves.biblionumber=$$res{biblionumber}
         reserves.reservenumber=$$res{reservenumber}
         borrowernumber=$coBorrowernumber is same as hold's borrower
      |;
   }

   ## sanity check on status of hold.  It *should* be in Waiting mode and
   ## no longer in the bib's holds list priorities.  That is, it was properly 
   ## checked in (and transferred, if applicable).
   if (($$res{found} ~~ 'W') && ($$res{priority} ~~ 0)) {
      ## do nothing right now.
   }
   else { ## sigh, this means Workflow wasn't followed.
      ## If we get here, the patron is checking out an item that fills the
      ## hold, whether it was bib-level or item-level.
      
      ## for whatever reason, the item is still in the bib's holds queue
      ## with a priority number and was never pulled to the holds shelf.
      if ($$res{priority} != 0) {
         ## do nothing
      }
      elsif ($$res{priority} != 1) {
         die qq|Unexpected workflow: reserve priority is not at the top of bib's 
            queue (priority=1).  Cannot checkout to borrower 
            (borrowernumber=$coBorrowernumber) lower in precedence in queue 
            (priority=$$res{priority}) without override
         |;
      }

      ## Let's see... hold is still set to 'in transit'
      if ($$res{found} ~~ 'T') {
         ## look for the item in the branchtransfers table.
         ## maybe they forgot to tell Koha that it has arrived?
         $sth = $dbh->prepare('
            SELECT * FROM branchtransfers
             WHERE itemnumber = ?
               AND tobranch   = ?
               AND datearrived IS NULL');
         $sth->execute($coItemnumber,$currBranch);
         my $bt = $sth->fetchrow_hashref() // {};
         if ($bt) { ## it was never set to arrived, but here we are already at checkout
            $sth = $dbh->prepare('
               UPDATE branchtransfers
                  SET datearrived = NOW()
                WHERE datearrived IS NULL
                  AND itemnumber = ?
                  AND tobranch   = ?');
            $sth->execute($coItemnumber,$currBranch);
         }
      }
      elsif ($$res{found} ~~ 'F') {
         ## old data from legacy ModReserveFill() or otherwise messed up workflow
         die qq|Cannot handle reserves.found='F' still in reserves table at checkout.
            Should have been moved to old_reserves (reservenumber=$$res{reservenumber})
         |;
      }
   }

   ## set the reserve to fill
   $sth = $dbh->prepare(q|
      UPDATE reserves
         SET found         = 'F',
             priority      = 0
       WHERE reservenumber = ?|);
   $sth->execute($$res{reservenumber});

   _moveToOldReserves($$res{reservenumber});

   ## force removal from Holds Queue Report
   $sth = $dbh->prepare('
      DELETE FROM tmp_holdsqueue
       WHERE reservenumber = ?');
   $sth->execute($$res{reservenumber});
   
   ## fix other holds' priorities.
   _NormalizePriorities($$res{biblionumber});

   return 1;
}

sub ModReserveFillCheckin
{
   my $res = shift; # the reserves hash should be complete
   
   ## how many days it's going to sit on the hold shelf awaiting pickup
   my $delay = C4::Context->preference('ReservesMaxPickupDelay');
   my $expirationdate = '';
   if ($delay) {
      $expirationdate = ",expirationdate=DATE_ADD(NOW(),INTERVAL $delay DAY)";
   }
   else {
      $expirationdate = ",expirationdate=NULL";
   }
   my $dbh = C4::Context->dbh;
   my $query = "UPDATE reserves
                   SET priority         = 0
                       $expirationdate ,
                       waitingdate      = NOW()
                 WHERE reservenumber    = ?";
   my $sth = $dbh->prepare($query);
   $sth->execute($$res{reservenumber});

   ## delete from Holds Queue
   $sth = $dbh->prepare('DELETE FROM tmp_holdsqueue
      WHERE reservenumber = ?');
   $sth->execute($$res{reservenumber});
  
   return 1; # return true on success
}

sub ModReserveTrace
{
   my $res = shift;
   my $dbh = C4::Context->dbh;
   my $sth;
   
   my $itemnumber = $$res{itemnumber};
   $$res{item_level_request} = 0;
   unless ($itemnumber) { # bib-level hold
      ## get the targeted item from tmp_holdsqueue table
      $sth = $dbh->prepare('SELECT itemnumber
         FROM tmp_holdsqueue
        WHERE reservenumber = ?');
      $sth->execute($$res{reservenumber});
      $itemnumber = ($sth->fetchrow_array)[0];
   }
   else {
      $$res{item_level_request} = 1;
   }
   
   ## update item's LOST status
   ## get the authorised_value of 'trace'
   $sth = $dbh->prepare("SELECT authorised_value
      FROM authorised_values
     WHERE category = 'LOST'
       AND LCASE(lib) = 'trace'");
   $sth->execute();
   my $traceAuthVal = ($sth->fetchrow_array)[0];
   die "No authorised value 'Trace' set for category 'LOST'\n" 
   unless defined $traceAuthVal;   
   $dbh->do(q|
      UPDATE items
         SET itemlost    = ?
       WHERE itemnumber  = ?
      |, undef,
   $traceAuthVal, $itemnumber);

   if ($$res{item_level_request}) { ## item-level request
      ## suspend the hold, retain its priority
      my $sql = "UPDATE reserves
              SET    found            = 'S',
                     expirationdate   = NULL
              WHERE  reservenumber    = ?";
      $dbh->do($sql, undef, $$res{reservenumber});
   }
   else { ## bib-level request
      ## do nothing, just remove from tmp_holdsqueue..
      ## this effectively starts the filling of this reserve over
      ## at, hopefully, holdingbranch=pickupbranch upon next
      ## run of build_holds_queue.pl
   }

   $sth = $dbh->prepare("DELETE FROM tmp_holdsqueue
       WHERE reservenumber = ?");
   $sth->execute($$res{reservenumber});
   return 1;
}

=item ModReserveStatus

&ModReserveStatus($itemnumber, $newstatus, $reservenumber);

Update the reserve status for the active (priority=0) reserve.

$itemnumber is the itemnumber the reserve is on

$newstatus is the new status.

$reservenumber is the reserves.reservenumber

=cut

sub ModReserveStatus {
    #first : check if we have a reservation for this item .
    my ($itemnumber, $newstatus, $reservenumber) = @_;
    $debug and warn "ModReserveStatus($itemnumber, $newstatus, $reservenumber)";
    my $dbh          = C4::Context->dbh;
    my ($query,$sth,$sth_set);

# Need to account for hold expiration date, since it hasn't been calculated
# at this point.
    my $holdperiod = C4::Context->preference('ReservesMaxPickUpDelay');
    if (defined($holdperiod) && ($holdperiod > 0)) {
      my ($holdexpyear,$holdexpmonth,$holdexpday) = Today();
      my $holdstartdate = C4::Dates->new(sprintf "%02d/%02d/%04d",$holdexpmonth,$holdexpday,$holdexpyear, 'us');

      # Grab branch for calendar purposes
      $sth = $dbh->prepare("SELECT branchcode FROM reserves WHERE reservenumber=?");
      $sth->execute($reservenumber);
      my ($branch) = $sth->fetchrow;

      # Check to see if hold expiration date falls on a closed library day.
      # Note the useDaysMode syspref will need to be set to Calendar for
      # the code to advance to the next non-closed day.
      my $calendar = C4::Calendar->new( branchcode => $branch);
      my $holdexpdate  = $calendar->addDate($holdstartdate, $holdperiod);
      my $sqlexpdate = $holdexpdate->output('iso');
      $query = "
          UPDATE reserves
          SET    found = ?,
                 waitingdate = now(),
                 expirationdate = '$sqlexpdate'
          WHERE itemnumber = ?
            AND found IS NULL
            AND priority = 0
      ";
      $sth_set = $dbh->prepare($query);
      $sth_set->execute( $newstatus, $itemnumber );
    }
    else {
      $query = "
          UPDATE reserves
          SET    found=?,
                 waitingdate = now()
          WHERE itemnumber=?
             AND found IS NULL
             AND priority = 0
      ";
      $sth_set = $dbh->prepare($query);
      $sth_set->execute( $newstatus, $itemnumber );
    }
    _NormalizePriorities(GetReserve($reservenumber)->{biblionumber});

    if ( C4::Context->preference("ReturnToShelvingCart") && $newstatus ) {
      CartToShelf( $itemnumber );
    }
}

=item ModReserveAffect

&ModReserveAffect($itemnumber,$borrowernumber,$diffBranchSend);

This function affect an item and a status for a given reserve
The itemnumber parameter is used to find the biblionumber.
with the biblionumber & the borrowernumber, we can affect the itemnumber
to the correct reserve.

if $transferToDo is not set, then the status is set to "Waiting" as well.
otherwise, a transfer is on the way, and the end of the transfer will 
take care of the waiting status
=cut

sub ModReserveAffect {
    my ( $itemnumber, $borrowernumber,$transferToDo, $reservenumber ) = @_;
    my $dbh = C4::Context->dbh;
    # we want to attach $itemnumber to $borrowernumber, find the biblionumber
    # attached to $itemnumber
    my $sth = $dbh->prepare('SELECT biblionumber FROM items WHERE itemnumber=? LIMIT 1');
    $sth->execute($itemnumber);
    my ($biblionumber) = $sth->fetchrow;

    # get request - need to find out if item is already
    # waiting in order to not send duplicate hold filled notifications
    my $request = GetReserveInfo($borrowernumber, $biblionumber);
    my $already_on_shelf = ($request && $request->{found} ~~ 'W') ? 1 : 0;

    # If we affect a reserve that has to be transfered, don't set to Waiting
    my $query;
    if ($transferToDo) {
        $query = q{
            UPDATE reserves
            SET    priority = 0,
                   itemnumber = ?,
                   found = 'T'
            WHERE reservenumber = ?
        };
    }
    else {
    # affect the reserve to Waiting as well.
      my $holdperiod = C4::Context->preference('ReservesMaxPickUpDelay');
      if ((!defined($holdperiod)) || ($holdperiod ~~ '') || ($holdperiod == 0)) {
        $query = "
            UPDATE reserves
            SET     priority = 0,
                    found = 'W',
                    waitingdate=now(),
                    itemnumber = ?
            WHERE reservenumber = ?
        ";
      }
      else {
        my ($holdexpyear,$holdexpmonth,$holdexpday) = Today();
        my $holdstartdate = C4::Dates->new(sprintf "%02d/%02d/%04d",$holdexpmonth,$holdexpday,$holdexpyear, 'us');

        # Grab branch for calendar purposes
        $sth = $dbh->prepare("SELECT branchcode FROM reserves WHERE reservenumber=?");
        $sth->execute($reservenumber);
        my ($branch) = $sth->fetchrow;

        # Check to see if hold expiration date falls on a closed library day.
        # Note the useDaysMode syspref will need to be set to Calendar for
        # the code to advance to the next non-closed day.
        my $calendar = C4::Calendar->new( branchcode => $branch);
        my $holdexpdate  = $calendar->addDate($holdstartdate, $holdperiod);
        my $sqlexpdate = $holdexpdate->output('iso');
        $query = "
            UPDATE reserves
            SET    priority = 0,
                   found = 'W',
                   waitingdate=now(),
                   itemnumber = ?,
                   expirationdate='$sqlexpdate'
            WHERE  reservenumber = ?
        ";
      }
    }
    $sth = $dbh->prepare($query);
    $sth->execute( $itemnumber, $reservenumber );
    _NormalizePriorities( $biblionumber );
    _koha_notify_reserve( $itemnumber, $borrowernumber, $biblionumber, $reservenumber ) if ( !$transferToDo && !$already_on_shelf && C4::Context->preference('EnableHoldOnShelfNotice'));

    if ( C4::Context->preference("ReturnToShelvingCart") ) {
      CartToShelf( $itemnumber );
    }

    return;
}

=item ModReserveCancelAll

($messages,$nextreservinfo) = &ModReserveCancelAll($reservenumber,$itemnumber);

    function to cancel reserv,check other reserves, and transfer document if it's necessary

=cut

sub ModReserveCancelAll {
    my ( $reservenumber, $itemnumber ) = @_;
    my $messages;
    my $nextreservinfo;

    #step 1 : cancel the reservation
    my $CancelReserve = CancelReserve( $reservenumber );

    #step 2 launch the subroutine of the others reserves
    ( $messages, $nextreservinfo ) = GetOtherReserves($itemnumber);

    return ( $messages, $nextreservinfo );
}

=item ModReserveMinusPriority

&ModReserveMinusPriority($itemnumber,$borrowernumber,$biblionumber,$reservenumber)

Reduce the values of queuded list     

=cut

sub ModReserveMinusPriority {
    my ( $itemnumber, $borrowernumber, $biblionumber, $reservenumber ) = @_;
    $debug and warn "ModReserveMinusPriority( $itemnumber, $borrowernumber, $biblionumber )";
    #first step update the value of the first person on reserv
    my $dbh   = C4::Context->dbh;
    my $query = "
        UPDATE reserves
        SET    priority = 0 , itemnumber = ? 
        WHERE  reservenumber=?
    ";
    my $sth_upd = $dbh->prepare($query);
    $sth_upd->execute( $itemnumber, $reservenumber );
    # second step update all others reservs
    _FixPriority( $reservenumber, '0' );
}

sub GetReserve
{
   my $reservenumber = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('SELECT * FROM reserves WHERE reservenumber = ?');
   $sth->execute($reservenumber);
   return $sth->fetchrow_hashref();
}

=item GetReserveInfo

&GetReserveInfo($borrowernumber,$biblionumber);

 Get item and borrower details for a current hold.
 Current implementation this query should have a single result.
=cut

sub GetReserveInfo {
	my ( $borrowernumber, $biblionumber ) = @_;
    my $dbh = C4::Context->dbh;
	my $strsth="SELECT reservedate, reservenotes, reserves.borrowernumber,
				reserves.biblionumber, reserves.branchcode,
				notificationdate, reminderdate, priority, found,
				firstname, surname, phone, 
				email, address, address2,
				cardnumber, city, zipcode,
				biblio.title, biblio.author,
				items.holdingbranch, items.itemcallnumber, items.itemnumber, 
				homebranch, barcode, notes
			FROM reserves left join items 
				ON items.itemnumber=reserves.itemnumber , 
				borrowers, biblio 
			WHERE 
				reserves.borrowernumber=?  &&
				reserves.biblionumber=? && 
				reserves.borrowernumber=borrowers.borrowernumber && 
				reserves.biblionumber=biblio.biblionumber ";
	my $sth = $dbh->prepare($strsth); 
	$sth->execute($borrowernumber,$biblionumber);

	my $data = $sth->fetchrow_hashref;
	return $data;

}

=item IsAvailableForItemLevelRequest

=over 4

my $is_available = IsAvailableForItemLevelRequest($itemnumber);

=back

Checks whether a given item record is available for an
item-level hold request.  An item is available if

* it is not lost
* it is not damaged (if syspref AllowHoldsOnDamagedItems=Off)
* it is not withdrawn
* it is not suppressed
* it is not marked notforloan (is false)
* it is not set to trace or other blocking status
* it is not on loan (see below)
* it is not notforhold by itemtype
* itemstatus
      holdsallowed = 1
      holdsfilled  = 1
Does not check
* issuing rule blocks
* is sitting on the hold shelf (reserves.found = 'W'aiting)

Whether or not the item is currently on loan is 
also checked - if the AllowOnShelfHolds system preference
is ON, an item can be requested even if it is currently
on loan to somebody else.  If the system preference
is OFF, an item that is currently checked out cannot
be the target of an item-level hold request.

Note that IsAvailableForItemLevelRequest() does not
check if the staff operator is authorized to place
a request on the item - in particular,
this routine does not check IndependantBranches
and canreservefromotherbranches.

Item *may* be held for reserve even if

* it is currently in transit

=cut

sub IsAvailableForItemLevelRequest {
    my $itemnumber = shift;
    my $item = GetItem($itemnumber);
    my $dbh = C4::Context->dbh;
    my $sth;

    return 0 if $$item{itemlost};
    return 0 if $$item{wthdrawn};
    return 0 if $$item{suppress};
    if ($$item{otherstatus}) {
       $sth = $dbh->prepare('SELECT holdsallowed,holdsfilled
          FROM itemstatus
         WHERE statuscode = ?');
       $sth->execute($$item{otherstatus});
       my($holdsallowed,$holdsfilled) = $sth->fetchrow_array();
       return 0 unless ($holdsallowed && $holdsfilled);
    }

    ## check in transit .. deprecated
    #$sth = $dbh->prepare('SELECT * FROM branchtransfers
    #   WHERE itemnumber = ?');
    #$sth->execute($itemnumber);
    #while (my $transfers = $sth->fetchrow_hashref) {
    #  return 0 if (!defined($transfers->{'datearrived'}));
    #}
    #### one just can't cancel the hold, that's all

    # must check the notforloan setting of the itemtype
    # FIXME - a lot of places in the code do this
    #         or something similar - need to be
    #         consolidated
    # ALSO - checks notforhold
    my $notforloan_query;
    if (C4::Context->preference('item-level_itypes')) {
        $notforloan_query = "SELECT itemtypes.notforloan,itemtypes.notforhold
                             FROM items
                             JOIN itemtypes ON (itemtypes.itemtype = items.itype)
                             WHERE itemnumber = ?";
    } else {
        $notforloan_query = "SELECT itemtypes.notforloan,itemtypes.notforhold
                             FROM items
                             JOIN biblioitems USING (biblioitemnumber)
                             JOIN itemtypes ON ( itemtypes.itemtype = biblioitems.itemtype )
                             WHERE itemnumber = ?";
    }
    $sth = $dbh->prepare($notforloan_query);
    $sth->execute($itemnumber);
    my $notforloan_per_itemtype = 0;
    my($notforloan,$notforhold) = $sth->fetchrow_array();
    return 0 if $notforhold;
    if ($notforloan) {
        $notforloan_per_itemtype = 1 if $notforloan;
    }

    my $available_per_item = 1;
    $available_per_item = 0 if $item->{itemlost} or
                               ( $item->{notforloan} > 0 ) or
                               ($item->{damaged} and not C4::Context->preference('AllowHoldsOnDamagedItems')) or
                               $item->{wthdrawn} or
                               $notforloan_per_itemtype;

    if (C4::Context->preference('AllowOnShelfHolds')) {
      return $available_per_item;
    } else {
      return ($available_per_item and $item->{onloan});
    }
}

sub CanHoldMultipleItems {
  my ( $itemtype, $user ) = @_;
  
  if ($user ~~ 'opac') {
    my @multi_itemtypes = split( / /, C4::Context->preference('AllowMultipleHoldsPerBib') );
    for my $mtype ( @multi_itemtypes ) {
      if ( $itemtype ~~ $mtype ) {
        return 1;
      }
    }
    return 0;
  }
  else {
    return 1;
  }

}

sub fixPrioritiesOnItemMove
{
   my $biblionumber = shift;
   my $dbh = C4::Context->dbh;
   my $sth;

   ## check to see if we have conflicting priorities
   $sth = $dbh->prepare('SELECT reservenumber,priority
      FROM reserves
     WHERE biblionumber = ?
       AND priority > 0');
   $sth->execute($biblionumber);
   my %seen = ();
   my $reshuffle = 0;
   while (my $row = $sth->fetchrow_hashref()) {
      if ($seen{$$row{priority}}) {
         $reshuffle = 1;
         last;
      }
      else {
         $seen{$$row{priority}} = $$row{reservenumber};
      }
   }
   return 1 unless $reshuffle;

   ## more than one reserve has the same priority number.
   ## ok, this is what they want: integrate the item-level hold to
   ## the bib's holds queue, reshuffling the priorities based on datetime
   $sth = $dbh->prepare('SELECT reservenumber,reservedate
      FROM reserves
     WHERE biblionumber = ?
       AND priority > 0
     ORDER BY reservedate ASC ');
   $sth->execute($biblionumber);
   my $c = 1;
   while(my $row = $sth->fetchrow_hashref()) {
      my $sth2 = $dbh->prepare('UPDATE reserves
         SET priority      = ?
       WHERE reservenumber = ?');
      $sth2->execute($c,$$row{reservenumber});
      $c++;
   }
   return 1;
}

sub _NormalizePriorities {
    my $biblionumber = shift or croak 'Must supply biblionumber';
    my $dbh = C4::Context->dbh;

    # Important part is to order by priority *and* timestamp.
    # This allows the most recently modified instance of all instances
    # of identical priority to now take the lowest priority, which is
    # what we want in most cases.
    my $query = q{
        SELECT reservenumber
        FROM   reserves
        WHERE  biblionumber = ?
          AND  (found IS NULL OR found = 'S')
          AND  priority > 0
        ORDER BY priority ASC, timestamp ASC
    };
    my $reserves_list
        = $dbh->selectcol_arrayref($query, undef, $biblionumber);

    # Just iterate over the list of reservenumbers and set their
    # priorities to be an increasing monotonic sequence.
    $query = q{
        UPDATE reserves
        SET    priority = ?
        WHERE  reservenumber = ?
    };
    my $sth = $dbh->prepare_cached($query);
    for ( my $j = 0 ; $j < @{$reserves_list} ; $j++ ) {
        $sth->execute( $j+1, $reserves_list->[$j] );
    }
    return;
}

=item _FixPriority

&_FixPriority($reservenumber, $rank);

 This splices the given reserve into the reserves list for all competing
 reserves at the given $rank. Then it updates all the other reserves with
 the new priorities. If there are duplicate priorities it will normalize
 them into being unique and sequential.

=cut 

sub _FixPriority {
    my ( $reservenumber, $rank ) = @_;
    my $dbh = C4::Context->dbh;

    if ( $rank ~~ 'del' ) {
        CancelReserve( $reservenumber );
        return;
    }

    my $reserve = GetReserve($reservenumber)
        // croak "Unable to find reserve ($reservenumber)";

    if ( $rank ~~ 'W' || $rank ~~ 0 ) {
        # make sure priority for waiting or in-transit items is 0
        $dbh->do(q{
            UPDATE reserves
            SET    priority = 0
            WHERE reservenumber = ?
        }, undef, $reservenumber);
    }
    else {
        $dbh->do(q{
            UPDATE reserves SET
            priority = ?
            WHERE reservenumber = ?
        }, undef, $rank, $reservenumber);
    }
    _NormalizePriorities($reserve->{biblionumber});
    return;
}

=item _Findgroupreserve

  @results = &_Findgroupreserve($itemnumber);

  Gets the priority-ordered list of reserves for a given item.

=cut

sub _Findgroupreserve {
    my $itemnumber = shift;

    my $query = q{
        SELECT reserves.reservenumber AS reservenumber,
               reserves.biblionumber AS biblionumber,
               reserves.borrowernumber AS borrowernumber,
               reserves.reservedate AS reservedate,
               reserves.branchcode AS branchcode,
               reserves.cancellationdate AS cancellationdate,
               reserves.found AS found,
               reserves.reservenotes AS reservenotes,
               reserves.waitingdate AS waitingdate,
               reserves.priority AS priority,
               reserves.timestamp AS timestamp,
               reserves.itemnumber AS itemnumber,
               borrowers.categorycode AS borrowercategory,
               borrowers.branchcode AS borrowerbranch
        FROM reserves
        JOIN items ON (items.biblionumber = reserves.biblionumber)
        JOIN itemtypes ON (items.itype = itemtypes.itemtype)
        JOIN borrowers ON (reserves.borrowernumber=borrowers.borrowernumber)
        WHERE reserves.biblionumber = items.biblionumber
          AND (found <> 'S' OR found IS NULL)
          AND (reserves.itemnumber IS NULL OR reserves.itemnumber = items.itemnumber)
          AND itemtypes.notforloan = 0
          AND items.notforloan <= 0
          AND reserves.reservedate <= NOW()
          AND items.itemnumber = ?
        ORDER BY priority ASC
    };

    return C4::Context->dbh->selectall_arrayref($query, {Slice => {}}, $itemnumber) // [];
}

=item _koha_notify_reserve

=over 4

_koha_notify_reserve( $itemnumber, $borrowernumber, $biblionumber );

=back

Sends a notification to the patron that their hold has been filled (through
ModReserveAffect, _not_ ModReserveFill)

=cut

sub _koha_notify_reserve {
    my ($itemnumber, $borrowernumber, $biblionumber, $reservenumber) = @_;

    my $dbh = C4::Context->dbh;
    my $borrower = C4::Members::GetMember( $borrowernumber );
    my $letter_code;
    my $print_mode = 0;
    my $messagingprefs;
    if ( $borrower->{'email'} || $borrower->{'smsalertnumber'} ) {
        $messagingprefs = C4::Members::Messaging::GetMessagingPreferences( { borrowernumber => $borrowernumber, message_name => 'Hold Filled' } );

        return if ( !defined( $messagingprefs->{'letter_code'} ) );
        $letter_code = $messagingprefs->{'letter_code'};
    } else {
        $letter_code = 'HOLD_PRINT';
        $print_mode = 1;
    }

    my $sth = $dbh->prepare("
        SELECT *
        FROM   reserves
        WHERE  reservenumber = ?
    ");
    $sth->execute( $reservenumber );
    my $reserve = $sth->fetchrow_hashref;
    if (C4::Context->preference('TalkingTechEnabled') && (!$borrower->{'email'})) {
      my $biblio = &GetBiblioData($biblionumber);
      my $item = &GetItem($itemnumber);
      my @items;
      $item->{'title'} = $biblio->{'title'};
      $item->{'date_due'} = $reserve->{'expirationdate'};
      push @items,$item;
      my $response = C4::Letters::CreateTALKINGtechMESSAGE($borrowernumber,\@items,'RESERVE','0');
      if ($response) {
        return;
      }
      else {
        $letter_code = 'HOLD_PRINT';
        $print_mode = 1;
      }
    }

    my $branch_details = GetBranchDetail( $reserve->{'branchcode'} );

    my $admin_email_address = $branch_details->{'branchemail'} || C4::Context->preference('KohaAdminEmailAddress');

    my $letter = getletter( 'reserves', $letter_code );
    die "Could not find a letter called '$letter_code' in the 'reserves' module" unless( $letter );

    C4::Letters::parseletter( $letter, 'branches', $reserve->{'branchcode'} );
    C4::Letters::parseletter( $letter, 'borrowers', $borrowernumber );
    C4::Letters::parseletter( $letter, 'biblio', $biblionumber );
    C4::Letters::parseletter( $letter, 'reserves', $borrowernumber, $biblionumber );

    if ( $reserve->{'itemnumber'} ) {
        C4::Letters::parseletter( $letter, 'items', $reserve->{'itemnumber'} );
    }
    my $today = C4::Dates->new()->output();
    $letter->{'title'} =~ s/<<today>>/$today/g;
    $letter->{'content'} =~ s/<<today>>/$today/g;
    $letter->{'content'} =~ s/<<[a-z0-9_]+\.[a-z0-9]+>>//g; #remove any stragglers

    if ( $print_mode ) {
        C4::Letters::EnqueueLetter( {
            letter => $letter,
            borrowernumber => $borrowernumber,
            message_transport_type => 'print',
        } );
        
        return;
    }

    if ( grep { $_ ~~ 'email' } @{$messagingprefs->{transports}} ) {
        # aka, 'email' in ->{'transports'}
        C4::Letters::EnqueueLetter(
            {   letter                 => $letter,
                borrowernumber         => $borrowernumber,
                message_transport_type => 'email',
                from_address           => $admin_email_address,
            }
        );
    }

    if ( grep { $_ ~~ 'sms' } @{$messagingprefs->{transports}} ) {
        C4::Letters::EnqueueLetter(
            {   letter                 => $letter,
                borrowernumber         => $borrowernumber,
                message_transport_type => 'sms',
            }
        );
    }
}

=item _ShiftPriorityByDateAndPriority

=over 4

$new_priority = _ShiftPriorityByDateAndPriority( $biblionumber, $reservedate, $priority );

=back

This increments the priority of all reserves after the one
 with either the lowest date after C<$reservedate>
 or the lowest priority after C<$priority>.

It effectively makes room for a new reserve to be inserted with a certain
 priority, which is returned.

This is most useful when the reservedate can be set by the user.  It allows
 the new reserve to be placed before other reserves that have a later
 reservedate.  Since priority also is set by the form in reserves/request.pl
 the sub accounts for that too.

=cut

sub _ShiftPriorityByDateAndPriority {
    my ( $biblio, $resdate, $new_priority ) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT priority FROM reserves WHERE biblionumber = ? AND ( reservedate > ? OR priority > ? ) ORDER BY priority ASC LIMIT 1";
    my $sth = $dbh->prepare( $query );
    $sth->execute( $biblio, $resdate, $new_priority );
    my $min_priority = $sth->fetchrow;
    # if no such matches are found, $new_priority remains as original value
    $new_priority = $min_priority if ( $min_priority );

    # Shift the priority up by one; works in conjunction with the next SQL statement
    $query = "UPDATE reserves
              SET priority = priority+1
              WHERE biblionumber = ?
              AND borrowernumber = ?
              AND reservedate = ?
              AND found IS NULL";
    my $sth_update = $dbh->prepare( $query );

    # Select all reserves for the biblio with priority greater than $new_priority, and order greatest to least
    $query = "SELECT borrowernumber, reservedate FROM reserves WHERE priority >= ? AND biblionumber = ? ORDER BY priority DESC";
    $sth = $dbh->prepare( $query );
    $sth->execute( $new_priority, $biblio );
    while ( my $row = $sth->fetchrow_hashref ) {
	$sth_update->execute( $biblio, $row->{borrowernumber}, $row->{reservedate} );
    }

    return $new_priority;  # so the caller knows what priority they wind up receiving
}

sub SuspendReserve {
    my ( $reservenumber, $resumedate ) = @_;

    my $reserve = GetReserve($reservenumber);
    croak sprintf 'Nonexistent reserve (%d)', $reservenumber unless $reserve;
    croak 'Cannot suspend waiting or in-transit holds' if ([qw(W T)] ~~ ($reserve->{found} // ''));

    C4::Context->dbh->do(q{
            UPDATE reserves SET
              found = 'S',
              waitingdate = ?
            WHERE reservenumber = ?
            }, undef, $resumedate, $reservenumber
        );

    _FixPriority( $reservenumber, $reserve->{priority} );
    return;
}

sub ResumeReserve {
    my ( $reservenumber ) = @_;

    my $reserve = GetReserve($reservenumber);
    croak sprintf 'Nonexistent reserve (%d)', $reservenumber unless $reserve;
    return if ($reserve->{found} // '') ne 'S';

    C4::Context->dbh->do(q{
            UPDATE reserves SET
              found       = NULL,
              waitingdate = NULL
            WHERE reservenumber = ?
            }, undef, $reservenumber
        );

    _FixPriority( $reservenumber, $reserve->{priority} );
    return;
}

sub ResumeSuspendedReservesWithResumeDate {
    my $dbh = C4::Context->dbh;
    my $sth;
    my $query;

    $query = q{SELECT reservenumber FROM reserves WHERE found = 'S' AND DATE(waitingdate) <= DATE(NOW())};
    $sth = $dbh->prepare( $query );
    my $data = $sth->execute();
    my $res = $sth->fetchall_arrayref();
    $sth->finish();

    foreach my $r ( @{$res} ) {
      ResumeReserve( @$r );
    }
}

=back

=head1 AUTHOR

Koha Developement team <info@koha.org>

=cut

1;
__END__
