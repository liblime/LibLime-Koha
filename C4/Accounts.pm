package C4::Accounts;

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


use strict;
use C4::Context;
use C4::Stats;
use C4::Members;
use C4::Items;
use C4::LostItems;
use C4::Circulation;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	# set the version for version checking
	$VERSION = 3.03;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&recordpayment &makepayment
		&getnextacctno &reconcileaccount &getcharges &getcredits
		&ReversePayment
		&getrefunds &chargelostitem makepartialpayment
	);
}

=head1 NAME

C4::Accounts - Functions for dealing with Koha accounts

=head1 SYNOPSIS

use C4::Accounts;

=head1 DESCRIPTION

The functions in this module deal with the monetary aspect of Koha,
including looking up and modifying the amount of money owed by a
patron.

## FIXME: Please complete this list -hQ
Account types (accounttype):

   A     ??
   CR    credit
   F     static fine/fee
   FOR   fine forgiven
   FU    fine update (periodically accessed)
   L     ?lost ??
   Pay   payment
   RCR   refund owed
   REF   refund issued
   Rent  rental fee
   Rep   ?replacement ??
   Res   ??

=head1 FUNCTIONS

=cut

sub GetLine
{
   my($borrowernumber,$accountno) = @_;
   return {} unless ($borrowernumber && $accountno);
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('SELECT * FROM accountlines
      WHERE borrowernumber = ?
        AND accountno      = ?');
   $sth->execute($borrowernumber,$accountno);
   return $sth->fetchrow_hashref() // {};
}

=head2 recordpayment

  &recordpayment($borrowernumber, $payment);

Record payment by a patron. C<$borrowernumber> is the patron's
borrower number. C<$payment> is a floating-point number, giving the
amount that was paid. 

Amounts owed are paid off oldest first. That is, if the patron has a
$1 fine from Feb. 1, another $1 fine from Mar. 1, and makes a payment
of $1.50, then the oldest fine will be paid off in full, and $0.50
will be credited to the next one.

=cut

## This is a dispersal payment
sub recordpayment 
{

    #here we update the account lines
    my ( $borrowernumber, $data ) = @_;
    my $dbh        = C4::Context->dbh;
    my $newamtos   = 0;
    my $accdata    = "";
    my $branch     = C4::Context->userenv->{'branch'};
    my $amountleft = $data;

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);

    # get lines with outstanding amounts to offset
    my $sth = $dbh->prepare("SELECT * FROM accountlines
      WHERE (borrowernumber = ?) 
        AND (amountoutstanding<>0)
   ORDER BY accountno DESC
    ");
    $sth->execute($borrowernumber);

    # offset transactions
    while ( ( $accdata = $sth->fetchrow_hashref ) and ( $amountleft > 0 ) ) {
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $paydate  = C4::Dates->new()->output;
        my $usth     = $dbh->prepare("UPDATE accountlines 
            SET amountoutstanding = ?,
                description       = CONCAT(description,', paid at no.$nextaccntno $paydate')
          WHERE borrowernumber    = ? 
            AND accountno         = ?
        ");
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
#        $usth = $dbh->prepare(
#            "INSERT INTO accountoffsets
#     (borrowernumber, accountno, offsetaccount,  offsetamount)
#     VALUES (?,?,?,?)"
#        );
#        $usth->execute( $borrowernumber, $accdata->{'accountno'},
#            $nextaccntno, $newamtos );
        $usth->finish;
    }

    # create new line
    my $user = C4::Context->userenv->{'id'};
    my $usth = $dbh->prepare(qq|
      INSERT INTO accountlines
  (borrowernumber, accountno,date,amount,description,accounttype,amountoutstanding)
  VALUES (?,?,now(),?,"Payment, Thanks (-$user)",'Pay',?)|
    );
    $usth->execute( $borrowernumber, $nextaccntno, 0 - $data, 0 - $amountleft );
    $usth->finish;
    C4::Stats::UpdateStats( $branch, 'payment', $data, '', '', '', $borrowernumber, $nextaccntno );
    $sth->finish;

}

sub MemberAllAccounts
{
   my %g   = @_;
   my $dbh = C4::Context->dbh;
   my $sth;

   if ($g{total_only}) {
      $sth = $dbh->prepare('
         SELECT SUM(amountoutstanding)
           FROM accountlines
          WHERE borrowernumber = ?');
      $sth->execute($g{borrowernumber});
      return ($sth->fetchrow_array)[0];
   }

   my @vals  = ($g{borrowernumber});
   my $total = 0;
   my $sql = "
      SELECT accountlines.*,
             biblio.title,
             items.biblionumber,
             items.barcode
        FROM accountlines
   LEFT JOIN items ON  (accountlines.itemnumber = items.itemnumber)
   LEFT JOIN biblio ON (items.biblionumber      = biblio.biblionumber)
       WHERE accountlines.borrowernumber        = ?";
   if ($g{date}) {
      $sql .= ' AND date < ? ';
      push @vals, $g{date};
   }
   $sql .= ' ORDER BY accountno DESC';
   $sth = $dbh->prepare($sql);
   $sth->execute(@vals);
   my @all = ();
   while(my $row = $sth->fetchrow_hashref()) { 
      $total += ($$row{amountoutstanding} // 0);
      push @all, $row;
   }
   return $total, \@all;
}

sub writeoff
{
   my %g   = @_;
   die "No branch passed to writeoff()" unless $g{branch};
   $g{itemnumber} ||= undef; # store as null if not there
   if ($g{writeoff_all}) {
      my $dbh = C4::Context->dbh;
      my $sth = $dbh->prepare('SELECT amount,accountno
         FROM accountlines
        WHERE amountoutstanding >0
          AND borrowernumber = ?');
      $sth->execute($g{borrowernumber});
      while(my $row = $sth->fetchrow_hashref()) {
         $g{accountno} = $$row{accountno};
         $g{amount}    = $$row{amount};
         _writeoff_each(%g);
      }
      return 1;
   }
   return _writeoff_each(%g);
}

sub _writeoff_each
{
   my %g   = @_;
   my $dbh = C4::Context->dbh;
   my $sth;
   return unless ($g{accountno} && $g{borrowernumber});
   $g{itemnumber} ||= undef;
   unless ($g{amount}) {
      $sth = $dbh->prepare('SELECT amount FROM accountlines
         WHERE borrowernumber = ?
           AND accountno      = ?');
      $sth->execute($g{borrowernumber},$g{accountno});
      ($g{amount}) = $sth->fetchrow_array;
      return unless $g{amount};
   }
   die "Amount of accountno.$g{accountno} must be positive" if ($g{amount} <0);
   $sth = $dbh->prepare('UPDATE accountlines 
      SET amountoutstanding = 0
    WHERE accountno         = ?
      AND borrowernumber    = ?');
   $sth->execute($g{accountno},$g{borrowernumber});
   my $newno = getnextacctno($g{borrowernumber});
   $g{user} ||= '';
   $sth = $dbh->prepare("INSERT INTO accountlines (
         borrowernumber,
         accountno,
         itemnumber,
         date,
         amount,
         amountoutstanding,
         description,
         accounttype) VALUES(
         ?,?,?,NOW(),?,0,?,'W')");
   $sth->execute(
      $g{borrowernumber},
      $newno,
      $g{itemnumber},
      (-1 *$g{amount}),
      "Writeoff for no.$g{accountno} (-$g{user})"
   );
   C4::Stats::UpdateStats($g{branch},'writeoff',(-1 *$g{amount}),'',$g{itemnumber},'',
      $g{borrowernumber},$newno);
   if ($g{moditem_paidfor} && ($g{accounttype} ~~ 'L')) {
      if ($g{borrower}) {}
      else {
         $sth = $dbh->prepare('SELECT firstname,surname,cardnumber
            FROM borrowers
           WHERE borrowernumber = ?');
         $sth->execute();
         $g{borrower} = $sth->fetchrow_hashref();
      }
      foreach(qw(firstname surname cardnumber)) {
         $g{borrower}{$_} //= '';
      }
      my $bor = join(' ', 
         $g{borrower}{firstname},
         $g{borrower}{lastname},
         $g{borrower}{cardnumber}
      );
      C4::Items::ModItem({paidfor=>"Paid for by $bor " . C4::Dates->today()},
         undef, $g{itemnumber}
      );
   }
   return $newno;
}

=head2 makepayment

  &makepayment($borrowernumber, $acctnumber, $amount, $branchcode);

Records the fact that a patron has paid off the entire amount he or
she owes.

C<$borrowernumber> is the patron's borrower number. C<$acctnumber> is
the account that was credited. C<$amount> is the amount paid (this is
only used to record the payment. It is assumed to be equal to the
amount owed). C<$branchcode> is the code of the branch where payment
was made.

=cut

#'
# FIXME - I'm not at all sure about the above, because I don't
# understand what the acct* tables in the Koha database are for.
sub makepayment {
    #here we update both the accountoffsets and the account lines
    #updated to check, if they are paying off a lost item, we return the item
    # from their card, and put a note on the item record
    my ( $borrowernumber, $accountno, $amount, $user, $branch ) = @_;
    my $dbh = C4::Context->dbh;

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);
    my $newamtos    = 0;
    my $sth =
      $dbh->prepare(
        "SELECT * FROM accountlines WHERE  borrowernumber=? AND accountno=?");
    $sth->execute( $borrowernumber, $accountno );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;

    my $paydate = C4::Dates->new()->output;
    $dbh->do("UPDATE accountlines
        SET amountoutstanding = 0,
            description       = CONCAT(description, ', paid at no.$nextaccntno $paydate')
      WHERE borrowernumber    = $borrowernumber
        AND accountno         = $accountno
        "
    );

    # create new line
    $$data{description} //= '';
    my $payment = 0 - $amount;
    $sth = $dbh->prepare('INSERT INTO accountlines(
      borrowernumber,accountno,date,amount,description,itemnumber,
      accounttype,amountoutstanding) VALUES(
      ?,?,NOW(),?,?,?,?,?)');
    $sth->execute(
      $borrowernumber, 
      $nextaccntno,
      $payment,
      "Payment for no.$accountno $$data{description}, Thanks (-$user)", 
      $data->{itemnumber} || undef,
      'Pay', 
      0
    );

    # FIXME - The second argument to &UpdateStats is supposed to be the
    # branch code.
    # UpdateStats is now being passed $accountno too. MTJ
    C4::Stats::UpdateStats( $user, 'payment', $amount, '', '', '', $borrowernumber,
        $accountno );
    $sth->finish;
}

# makepayment needs to be fixed to handle partials till then this separate subroutine
# fills in
sub makepartialpayment {
    my ( $borrowernumber, $accountno, $amount, $user, $branch ) = @_;
    if (!$amount || $amount < 0) {
        return;
    }
    my $dbh = C4::Context->dbh;

    my $nextaccntno = getnextacctno($borrowernumber);
    my $newamtos    = 0;

    my $data = $dbh->selectrow_hashref(
        'SELECT * FROM accountlines WHERE  borrowernumber=? AND accountno=?',undef,$borrowernumber,$accountno);
    my $new_outstanding = $data->{amountoutstanding} - $amount;
    my $paydate = C4::Dates->new()->output;
    my $update = "UPDATE  accountlines 
        SET amountoutstanding = ?,
            description       = CONCAT(description, ', paid at no.$nextaccntno $paydate')
      WHERE borrowernumber    = ?
        AND accountno         = ?";
    $dbh->do( $update, undef, $new_outstanding, $borrowernumber, $accountno);

    # create new line
    my $insert = 'INSERT INTO accountlines (borrowernumber, accountno, date, amount, '
    .  'description, itemnumber, accounttype, amountoutstanding) '
    . ' VALUES (?, ?, now(), ?, ?, ?, ?, 0)';

    $dbh->do(  $insert, undef, $borrowernumber, $nextaccntno, (-1*$amount),
        "Payment for no.$accountno $$data{description}, Thanks (-$user)",$data->{itemnumber},'Pay');

    UpdateStats( $user, 'payment', (-1*$amount), '', '', '', $borrowernumber, $accountno );
    return 1;
}

# returns all relevant account lines for a given borrower and itemnumber
sub getAllAccountsByBorrowerItem
{
   my($borrowernumber,$itemnumber) = @_;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT * FROM accountlines
      WHERE borrowernumber = ?
        AND itemnumber     = ?");
   $sth->execute($borrowernumber,$itemnumber);
   my @all = ();
   while(my $row = $sth->fetchrow_hashref()) {
      push @all, $row;
   }
   return \@all;
}

=head2 getnextacctno

  $nextacct = &getnextacctno($borrowernumber);

Returns the next unused account number for the patron with the given
borrower number.

=cut

#'
# FIXME - Okay, so what does the above actually _mean_?
sub getnextacctno ($) {
    my ($borrowernumber) = shift or return undef;
    my $sth = C4::Context->dbh->prepare(
        "SELECT accountno+1 FROM accountlines
         WHERE    (borrowernumber = ?)
         ORDER BY accountno DESC
		 LIMIT 1"
    );
    $sth->execute($borrowernumber);
    return ($sth->fetchrow || 1);
}

sub RCR2REF
{
   my %g = @_;
   return unless ($g{borrowernumber} && $g{accountno});
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('SELECT * FROM accountlines
       WHERE accountno=? AND borrowernumber=?');
   $sth->execute($g{accountno},$g{borrowernumber});
   my $rec = $sth->fetchrow_hashref();
   return unless $rec;

   my $desc = $$rec{description};
   $desc    =~ s/^(Refund owed)/Refund issued/;
   $sth = $dbh->prepare(q|
      UPDATE accountlines
         SET accounttype       = 'REF',
             amountoutstanding = 0,
             description       = ?
       WHERE accountno         = ?
         AND borrowernumber    = ?|);
   $sth->execute($desc,$g{accountno},$g{borrowernumber});
   return 1;
}

sub refundBalance
{
   my %g = @_;
   return unless $g{borrowernumber};
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare(q|
      SELECT SUM(amountoutstanding)
        FROM accountlines
       WHERE borrowernumber = ?|);
   $sth->execute($g{borrowernumber});
   my $sum = ($sth->fetchrow_array)[0];
   return if $sum >= 0;
   my $newno = getnextacctno($g{borrowernumber});
   $sth = $dbh->prepare(q|
      INSERT INTO accountlines(
         date,
         accountno,
         borrowernumber,
         description,
         amount,
         amountoutstanding,
         accounttype
      ) VALUES (NOW(),?,?,?,?,?,?)|);
   $sth->execute(
      $newno,
      $g{borrowernumber},
      'Refund account total balance credit for payment(s)',
      $sum,
      0,
      'REF'
   );
   $sth = $dbh->prepare(qq|
      UPDATE accountlines
         SET accounttype       = 'CR',
             description       = CONCAT(description,', issued at no.$newno'),
             amountoutstanding = 0
       WHERE accounttype       = 'RCR'
         AND amountoutstanding < 0
         AND borrowernumber    = ?|);
   $sth->execute($g{borrowernumber});
   $sth = $dbh->prepare(q|
      UPDATE accountlines
         SET amountoutstanding = 0
       WHERE amountoutstanding > 0
         AND borrowernumber    = ?|);
   $sth->execute($g{borrowernumber});
   return 1;
}

sub makeClaimsReturned
{
   my $crval = C4::Context->preference('ClaimsReturnedValue');
   die "No ClaimsReturnedValue set in syspref" unless $crval;
   my($lost_item_id,$claims_returned,$nomoditem) = @_;

   $claims_returned ||= 0;
   $claims_returned   = 1 if $claims_returned;
   C4::LostItems::ModLostItem(id=>$lost_item_id,claims_returned=>$claims_returned);
   my $li = C4::LostItems::GetLostItemById($lost_item_id) // {};
   return 1 unless $li;
   if ($claims_returned) {
      return 1 unless C4::Context->preference('RefundReturnedLostItem');
   }
   else {
      if(!$nomoditem) {
         ## set category LOST authorised value to 1
         C4::Items::ModItemLost($$li{biblionumber},$$li{itemnumber},1);
      }
      ## possibly recharge a lost fee.  it will be recharged if it was previoulsy
      ## forgiven
      rechargeClaimsReturnedUndo($li);
      return 1;
   }

   ## RefundReturnedLostItem is ON and we have claims_returned true
   ## get the lost item in accountlines
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT * FROM accountlines
      WHERE borrowernumber = ?
        AND itemnumber     = ?
        AND accounttype    = 'L'
   ORDER BY accountno DESC");
   $sth->execute($$li{borrowernumber},$$li{itemnumber});
   my $data = $sth->fetchrow_hashref() // {};
   return 0 unless $$data{accountno}; ## never lost then suddenly set to Claims Returned
   C4::Items::ModItemLost($$li{biblionumber},$$li{itemnumber},$crval);

   ## see what else has been done regarding this lost item
   $sth = $dbh->prepare('SELECT * FROM accountlines
      WHERE borrowernumber = ?
        AND itemnumber     = ?
        AND accountno      > ?
   ORDER BY accountno DESC');
   $sth->execute($$li{borrowernumber},$$li{itemnumber},$$data{accountno});

   ## theoretically, you can't Writeoff, Pay, Lost Return, or Claims Returned
   ## on an item twice that's lost once.  This is for most recent lost
   my %c = ();
   while(my $row = $sth->fetchrow_hashref()) {
      $c{$$row{accounttype}} = $row;
   }
   my $cr_accountno = $c{FOR}{accountno} || getnextacctno($$li{borrowernumber});
   if (!$c{FOR}{amount}) {
      my $crdate = C4::Dates->new()->output;
      $dbh->do("UPDATE accountlines
         SET amountoutstanding = 0,
             description       = CONCAT(description,', claims returned at no.$cr_accountno $crdate')
       WHERE borrowernumber    = ?
         AND itemnumber        = ?
         AND accountno         = ?", undef,
         $$li{borrowernumber},
         $$li{itemnumber},
         $$data{accountno}); # doesn't go to LR, remains L
      $dbh->do("INSERT INTO accountlines (
            date,
            accountno,
            borrowernumber,
            itemnumber,
            accounttype,
            amount,
            amountoutstanding,
            description) VALUES(
         NOW(),?,?,?,'FOR',?,0,?)",undef,
         $cr_accountno,
         $$li{borrowernumber},
         $$li{itemnumber},
         (-1 *$$data{amount}),
         "Claims returned at no.$$data{accountno}"
      );
   }
   return 1 if $c{RCR};

   if ($$data{amountoutstanding} < $$data{amount}) {
      return unless $$data{description} =~ /paid at no\.\d+/;
      my $rcrAmount = -1 *($$data{amount} - $$data{amountoutstanding});
      return 1 unless $rcrAmount;
      my $pay_accountno = getnextacctno($$li{borrowernumber});
      $dbh->do("INSERT INTO accountlines (
            date,
            accountno,
            accounttype,
            borrowernumber,
            itemnumber,
            description,
            amount,
            amountoutstanding
            ) VALUES ( NOW(),?,'RCR',?,?,?,?,? )", undef,
         $pay_accountno,
         $$li{borrowernumber},
         $$li{itemnumber},
         "Refund owed at no.$$data{accountno} for payment on lost item Claims Returned",
         $rcrAmount,
         $rcrAmount,
      );
   }
   return 1;
}

sub rechargeClaimsReturnedUndo
{
   my $li = shift; # lost_items hash for the lost item
   my $dbh = C4::Context->dbh;
   my $sth;

   # first make sure the borrower hasn't already been charged for 
   # this item
   $sth = $dbh->prepare("SELECT * FROM accountlines
      WHERE borrowernumber = ?
        AND itemnumber     = ?
        AND accounttype    = 'L'
   ORDER BY timestamp DESC /* get only the latest */
      LIMIT 1");
   $sth->execute($$li{borrowernumber},$$li{itemnumber});
   my $acct = $sth->fetchrow_hashref();

   ## account was previously zero'd out
   if ($$acct{amountoutstanding} == 0) {
      ## get the replacement cost
      $sth = $dbh->prepare('
         SELECT replacementprice,
                biblioitemnumber 
           FROM items 
          WHERE itemnumber = ?');
      $sth->execute($$li{itemnumber});
      my($replacementprice,$biblioitemnumber) = $sth->fetchrow_array;
      if (($replacementprice == 0) || !$replacementprice) {
         ## get the replacement price by itemtype
         $sth = $dbh->prepare('
         SELECT itemtypes.replacement_price 
           FROM itemtypes,biblioitems
          WHERE itemtypes.itemtype = biblioitems.itemtype
            AND biblioitems.biblioitemnumber = ?');
         $sth->execute($biblioitemnumber);
         $replacementprice = ($sth->fetchrow_array)[0];
      }

      ## recharge the lost fee as a NEW line in the borrower's account
      my $accountno = getnextacctno($$li{borrowernumber});
      $sth = $dbh->prepare('INSERT INTO accountlines (
         accountno,
         itemnumber,
         amountoutstanding,
         date,
         description,
         accounttype,
         amount,
         borrowernumber)
         VALUES(?,?,?,NOW(),?,?,?,?)');
      $sth->execute(
         $accountno,
         $$li{itemnumber},
         $replacementprice,
         'Lost Item',
         'L',
         $replacementprice,
         $$li{borrowernumber}
      );
   }

   # else do nothing: borrower's already been charged for this item
   return 1;
}

sub chargelostitem{
# http://wiki.koha.org/doku.php?id=en:development:kohastatuses
# lost ==1 Lost, lost==2 longoverdue, lost==3 lost and paid for
# FIXME: itemlost should be set to 3 after payment is made, should be a warning to the interface that
# a charge has been added
# FIXME : if no replacement price, borrower just doesn't get charged?

    my $dbh = C4::Context->dbh();
    my ($itemnumber) = @_;

    # Pull default replacement price from itemtypes table in the event
    # items.replacementprice is not set
    my $sth=$dbh->prepare("SELECT lost_items.borrowernumber,
                                  lost_items.claims_returned,
                                  items.*,
                                  biblio.title,
                                  itemtypes.replacement_price 
                             FROM lost_items,items,biblio,itemtypes
                            WHERE lost_items.itemnumber = ?
                              AND lost_items.itemnumber = items.itemnumber
                              AND items.biblionumber    = biblio.biblionumber
                              AND items.itype           = itemtypes.itemtype");
    $sth->execute($itemnumber);
    my $lost=$sth->fetchrow_hashref() || return;
    return unless $$lost{borrowernumber};
    my $amount = $$lost{replacementprice} || $$lost{replacement_price} || 0;
    return unless $amount;

    # first make sure the borrower hasn't already been charged for this item
    $sth = $dbh->prepare("SELECT * from accountlines
        WHERE borrowernumber= ? 
          AND itemnumber    = ? 
          AND accounttype   = 'L'
     ORDER BY accountno DESC");
    $sth->execute($$lost{borrowernumber},$itemnumber);
    my $dat = $sth->fetchrow_hashref();
    return if $dat;

    my $accountno = getnextacctno($$lost{borrowernumber});
    $sth = $dbh->prepare("INSERT INTO accountlines
        (borrowernumber,accountno,date,amount,description,accounttype,amountoutstanding,itemnumber)
        VALUES (?,?,now(),?,?,'L',?,?)");
    return $sth->execute(
        $$lost{borrowernumber},
        $accountno,
        $amount,
        'Lost Item',
        $amount,
        $itemnumber
    );
    # FIXME: Log this ?
}

=head2 manualinvoice

args:

   borrowernumber req
   accounttype    req   pseudonymn type
   amount         req
   itemnumber     op
   description    op
   user           op

=cut

# I am guessing $user refers to the username (userid) of the logged in librarian -hQ

sub manualinvoice 
{
    my %g = @_;
    foreach(qw(amount borrowernumber)) { die "$_ is required" unless $g{$_} }
    $g{accounttype} ||= $g{type} || 'M';
    delete ($g{type});
    my $dbh = C4::Context->dbh;
    my %t = (
      'N'   ,'New Card',
      'F'   ,'Fine',
      'A'   ,'Account Management Fee',
      'M'   ,'Sundry',
      'L'   ,'Lost Item'
    );
   $g{notify_id} = 0;
   if (exists $t{$g{accounttype}}) {
      $g{description} = $t{$g{accounttype}} . ($g{description}? ", $g{description}" : '');
      $g{notify_id}   = 1;
   }
   if ($g{description} && $g{user}) {
      $g{description} .= " (-$g{user})";
   }
   delete $g{user};

   if (!!$g{notmanual}) {
      ## do nothing, don't alter description
      delete $g{notmanual};
   }
   else {
      if ($g{isCredit}) {
         $g{description} = "(Manual credit) $g{description}";
      }
      else {
         $g{description} = "(Manual invoice) $g{description}";
      }
   }

   if (exists $g{isCredit}) { delete $g{isCredit} }
   $g{accountno}         = getnextacctno($g{borrowernumber});
   $g{amountoutstanding} = $g{amount};
   my $sql = sprintf("INSERT INTO  accountlines (date,%s)
      VALUES(NOW(),%s)",
      join(',',keys %g),
      join(',',map{'?'}keys %g)
   );
   my $sth = $dbh->prepare($sql);
   $sth->execute(values %g);

    UpdateStats( my $branch = '', my $stattype = 'maninvoice', $g{amount}, my $other = $g{accounttype}, my $itemnum, my $itemtype, $g{borrowernumber}, $g{accountno});
    return 0;
}

=head2 fixcredit #### DEPRECATED

 $amountleft = &fixcredit($borrowernumber, $data, $barcode, $type, $user);

 This function is only used internally, not exported.

=cut

# This function is deprecated in 3.0

sub fixcredit {

    #here we update both the accountoffsets and the account lines
    my ( $borrowernumber, $data, $barcode, $type, $user ) = @_;
    my $dbh        = C4::Context->dbh;
    my $newamtos   = 0;
    my $accdata    = "";
    my $amountleft = $data;
    if ( $barcode ne '' ) {
        my $item        = GetBiblioFromItemNumber( '', $barcode );
        my $nextaccntno = getnextacctno($borrowernumber);
        my $query       = "SELECT * FROM accountlines WHERE (borrowernumber=?
    AND itemnumber=? AND amountoutstanding > 0)";
        if ( $type eq 'CL' ) {
            $query .= " AND (accounttype = 'L' OR accounttype = 'Rep')";
        }
        elsif ( $type eq 'CF' ) {
            $query .= " AND (accounttype = 'F' OR accounttype = 'FU' OR
      accounttype='Res' OR accounttype='Rent')";
        }
        elsif ( $type eq 'CB' ) {
            $query .= " and accounttype='A'";
        }

        #    print $query;
        my $sth = $dbh->prepare($query);
        $sth->execute( $borrowernumber, $item->{'itemnumber'} );
        $accdata = $sth->fetchrow_hashref;
        $sth->finish;
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
        $usth = $dbh->prepare(
            "INSERT INTO accountoffsets
     (borrowernumber, accountno, offsetaccount,  offsetamount)
     VALUES (?,?,?,?)"
        );
        $usth->execute( $borrowernumber, $accdata->{'accountno'},
            $nextaccntno, $newamtos );
        $usth->finish;
    }

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);

    # get lines with outstanding amounts to offset
    my $sth = $dbh->prepare(
        "SELECT * FROM accountlines
  WHERE (borrowernumber = ?) AND (amountoutstanding >0)
  ORDER BY date"
    );
    $sth->execute($borrowernumber);

    #  print $query;
    # offset transactions
    while ( ( $accdata = $sth->fetchrow_hashref ) and ( $amountleft > 0 ) ) {
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
        $usth = $dbh->prepare(
            "INSERT INTO accountoffsets
     (borrowernumber, accountno, offsetaccount,  offsetamount)
     VALUE (?,?,?,?)"
        );
        $usth->execute( $borrowernumber, $accdata->{'accountno'},
            $nextaccntno, $newamtos );
        $usth->finish;
    }
    $sth->finish;
    $type = "Credit " . $type;
    C4::Stats::UpdateStats( $user, $type, $data, $user, '', '', $borrowernumber );
    $amountleft *= -1;
    return ($amountleft);
}

=head2 refund

#FIXME : DEPRECATED SUB
 This subroutine tracks payments and/or credits against fines/charges
   using the accountoffsets table, which is not used consistently in
   Koha's fines management, and so is not used in 3.0 

=cut 

sub refund {

    #here we update both the accountoffsets and the account lines
    my ( $borrowernumber, $data ) = @_;
    my $dbh        = C4::Context->dbh;
    my $newamtos   = 0;
    my $accdata    = "";
    my $amountleft = $data * -1;

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);

    # get lines with outstanding amounts to offset
    my $sth = $dbh->prepare(
        "SELECT * FROM accountlines
  WHERE (borrowernumber = ?) AND (amountoutstanding<0)
  ORDER BY date"
    );
    $sth->execute($borrowernumber);

    #  print $amountleft;
    # offset transactions
    while ( ( $accdata = $sth->fetchrow_hashref ) and ( $amountleft < 0 ) ) {
        if ( $accdata->{'amountoutstanding'} > $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }

        #     print $amountleft;
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
        $usth = $dbh->prepare(
            "INSERT INTO accountoffsets
     (borrowernumber, accountno, offsetaccount,  offsetamount)
     VALUES (?,?,?,?)"
        );
        $usth->execute( $borrowernumber, $accdata->{'accountno'},
            $nextaccntno, $newamtos );
        $usth->finish;
    }
    $sth->finish;
    return ($amountleft);
}

sub getcharges {
	my ( $borrowerno, $timestamp, $accountno ) = @_;
	my $dbh        = C4::Context->dbh;
	my $timestamp2 = $timestamp - 1;
	my $query      = "";
	my $sth = $dbh->prepare(
			"SELECT * FROM accountlines WHERE borrowernumber=? AND accountno = ?"
          );
	$sth->execute( $borrowerno, $accountno );
	
    my @results;
    while ( my $data = $sth->fetchrow_hashref ) {
		push @results,$data;
	}
    return (@results);
}


sub getcredits {
	my ( $date, $date2 ) = @_;
	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare(
			        "SELECT * FROM accountlines,borrowers
      WHERE amount < 0 AND accounttype <> 'Pay' AND accountlines.borrowernumber = borrowers.borrowernumber
	  AND timestamp >=TIMESTAMP(?) AND timestamp < TIMESTAMP(?)"
      );  

    $sth->execute( $date, $date2 );                                                                                                              
    my @results;          
    while ( my $data = $sth->fetchrow_hashref ) {
		$data->{'date'} = $data->{'timestamp'};
		push @results,$data;
	}
    return (@results);
} 


sub getrefunds {
	my ( $date, $date2 ) = @_;
	my $dbh = C4::Context->dbh;
	
	my $sth = $dbh->prepare(
			        "SELECT *,timestamp AS datetime                                                                                      
                  FROM accountlines,borrowers
                  WHERE (accounttype = 'REF'
					  AND accountlines.borrowernumber = borrowers.borrowernumber
					                  AND date  >=?  AND date  <?)"
    );

    $sth->execute( $date, $date2 );

    my @results;
    while ( my $data = $sth->fetchrow_hashref ) {
		push @results,$data;
		
	}
    return (@results);
}

sub ReversePayment {
  my ( $borrowernumber, $accountno ) = @_;
  my $dbh = C4::Context->dbh;
  
  my $sth = $dbh->prepare('SELECT amountoutstanding FROM accountlines WHERE borrowernumber = ? AND accountno = ?');
  $sth->execute( $borrowernumber, $accountno );
  my $row = $sth->fetchrow_hashref();
  my $amount_outstanding = $row->{'amountoutstanding'};
  
  if ( $amount_outstanding <= 0 ) {
    $sth = $dbh->prepare('UPDATE accountlines SET amountoutstanding = amount * -1, description = CONCAT( description, " (Reversed)" ) WHERE borrowernumber = ? AND accountno = ?');
    $sth->execute( $borrowernumber, $accountno );
  } else {
    $sth = $dbh->prepare('UPDATE accountlines SET amountoutstanding = 0, description = CONCAT( description, " (Reversed)" ) WHERE borrowernumber = ? AND accountno = ?');
    $sth->execute( $borrowernumber, $accountno );
  }
}

sub MemberOwesOnDebtCollection {
  my ( $borrowernumber ) = @_;
  my $dbh = C4::Context->dbh;
  my $sql = "SELECT SUM(amountoutstanding) as stillOwing FROM accountlines, borrowers 
              WHERE borrowers.borrowernumber = ?
              AND borrowers.borrowernumber = accountlines.borrowernumber 
              AND accountlines.date <= borrowers.last_reported_date";
  my $sth = $dbh->prepare( $sql );
  $sth->execute( $borrowernumber );
  my $row = $sth->fetchrow_hashref;
  my $amount = $row->{'stillOwing'};
  
  return $amount;
}

END { }    # module clean-up code here (global destructor)

1;
__END__
sub returnlost{ # deprecated
    my ( $borrowernumber, $itemnum ) = @_;
    C4::Circulation::MarkIssueReturned( $borrowernumber, $itemnum );
    my $borrower = C4::Members::GetMember( $borrowernumber, 'borrowernumber' );
    my @datearr = localtime(time);
    my $date = ( 1900 + $datearr[5] ) . "-" . ( $datearr[4] + 1 ) . "-" . $datearr[3];
    my $bor = "$borrower->{'firstname'} $borrower->{'surname'} $borrower->{'cardnumber'}";
    C4::Items::ModItem({ paidfor =>  "Paid for by $bor $date" }, undef, $itemnum);
}


=head2 fixaccounts (removed)

  &fixaccounts($borrowernumber, $accountnumber, $amount);

#'
# FIXME - I don't understand what this function does.
sub fixaccounts {
    my ( $borrowernumber, $accountno, $amount ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "SELECT * FROM accountlines WHERE borrowernumber=?
     AND accountno=?"
    );
    $sth->execute( $borrowernumber, $accountno );
    my $data = $sth->fetchrow_hashref;

    # FIXME - Error-checking
    my $diff        = $amount - $data->{'amount'};
    my $outstanding = $data->{'amountoutstanding'} + $diff;
    $sth->finish;

    $dbh->do(<<EOT);
        UPDATE  accountlines
        SET     amount = '$amount',
                amountoutstanding = '$outstanding'
        WHERE   borrowernumber = $borrowernumber
          AND   accountno = $accountno
EOT
	# FIXME: exceedingly bad form.  Use prepare with placholders ("?") in query and execute args.
}

=cut


=head2 fixcredit #### DEPRECATED

 $amountleft = &fixcredit($borrowernumber, $data, $barcode, $type, $user);

 This function is only used internally, not exported.

=cut

# This function is deprecated in 3.0

sub fixcredit {

    #here we update both the accountoffsets and the account lines
    my ( $borrowernumber, $data, $barcode, $type, $user ) = @_;
    my $dbh        = C4::Context->dbh;
    my $newamtos   = 0;
    my $accdata    = "";
    my $amountleft = $data;
    if ( $barcode ne '' ) {
        my $item        = GetBiblioFromItemNumber( '', $barcode );
        my $nextaccntno = getnextacctno($borrowernumber);
        my $query       = "SELECT * FROM accountlines WHERE (borrowernumber=?
    AND itemnumber=? AND amountoutstanding > 0)";
        if ( $type eq 'CL' ) {
            $query .= " AND (accounttype = 'L' OR accounttype = 'Rep')";
        }
        elsif ( $type eq 'CF' ) {
            $query .= " AND (accounttype = 'F' OR accounttype = 'FU' OR
      accounttype='Res' OR accounttype='Rent')";
        }
        elsif ( $type eq 'CB' ) {
            $query .= " and accounttype='A'";
        }

        #    print $query;
        my $sth = $dbh->prepare($query);
        $sth->execute( $borrowernumber, $item->{'itemnumber'} );
        $accdata = $sth->fetchrow_hashref;
        $sth->finish;
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
        $usth = $dbh->prepare(
            "INSERT INTO accountoffsets
     (borrowernumber, accountno, offsetaccount,  offsetamount)
     VALUES (?,?,?,?)"
        );
        $usth->execute( $borrowernumber, $accdata->{'accountno'},
            $nextaccntno, $newamtos );
        $usth->finish;
    }

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);

    # get lines with outstanding amounts to offset
    my $sth = $dbh->prepare(
        "SELECT * FROM accountlines
  WHERE (borrowernumber = ?) AND (amountoutstanding >0)
  ORDER BY date"
    );
    $sth->execute($borrowernumber);

    #  print $query;
    # offset transactions
    while ( ( $accdata = $sth->fetchrow_hashref ) and ( $amountleft > 0 ) ) {
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
        $usth = $dbh->prepare(
            "INSERT INTO accountoffsets
     (borrowernumber, accountno, offsetaccount,  offsetamount)
     VALUE (?,?,?,?)"
        );
        $usth->execute( $borrowernumber, $accdata->{'accountno'},
            $nextaccntno, $newamtos );
        $usth->finish;
    }
    $sth->finish;
    $type = "Credit " . $type;
    C4::Stats::UpdateStats( $user, $type, $data, $user, '', '', $borrowernumber );
    $amountleft *= -1;
    return ($amountleft);

}


=head1 SEE ALSO

DBI(3)

=cut

