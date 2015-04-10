package C4::Accounts;

# Copyright 2000-2009
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
use C4::Context;
use C4::Stats;
use C4::Members;
use C4::Biblio;
use C4::Items;
use C4::LostItems;
use C4::Circulation;
use C4::Letters;
use C4::Branch;
use Koha::Money;

use List::Util qw[min max];
use Carp qw[cluck];
use Check::ISA;
use Date::Calc;
use Method::Signatures;

use DDP filters => {
            'DateTime'      => sub { $_[0]->ymd },
            'Koha::Money'   => sub { $_[0]->value } };
            
use vars qw($VERSION @ISA @EXPORT_OK $debug);

BEGIN {
	# set the version for version checking
	$VERSION = 3.03;
	$debug = $ENV{DEBUG} || 0;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT_OK = qw(
        &manualinvoice &manualcredit
		&getfee &getcharges &getcredits
        &getaccruingcharges
        &gettotalaccruing &gettotalowed
        &getmanualinvoicetypes
        &CreateFee &ApplyCredit
        &AddIssuingCharge

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

The accounting system uses three tables: fees, fee_transactions and payments.
All amounts are stored in fee_transactions.
The fees and payments tables store only metadata about a given fine or payment.

A fee is atomic in Koha, i.e. for each entry in the fees table, there
is one and only one entry in fee_transactions, with an amount > 0.
A fee should not change value; once the fee is assessed, all other transactions
against that fee should be credits.  This is not true of payments: a payment
may have many entries in fee_transactions linking portions of that payment
to various fees.
All debits to an account will have an entry in fees.
Only credits representing actual payments or applied credits will have entries in the payments table,
i.e. a payment entry is only necessary when further metadata about the credit is needed.
When a fee is forgiven or written off in full, only a fee_transactions entry is made.
A 'transaction' accounttype.class generates only a fee_transaction entry,
while a 'payment' accounttype.class generates both.  'payment' would be better named
'credit'; it represents a credit against the account that should persist even if it
is unlinked from the original fine (and applied to another).

Note all amounts are returned as Koha::Money objects.
Amounts should be passed as same, but can also be passed as a number.

To find the amount owed on a given fine:
select sum(amount) from fees LEFT JOIN fee_transactions on(fees.id = fee_transactions.fee_id) where fees.id=1;
To find the original amount due for the fine, we rely on the assumption that only one entry in fee_transactions
per fee_id may have an accounttype of class 'fee' (not enforced):
select amount from fees JOIN fee_transactions on(fees.id = fee_transactions.fee_id) where fees.id=1 and accounttype in (select accounttype from accounttypes where class='fee');
To find amount owed by a patron:

FIXME -- MISSING.

=head1 FUNCTIONS

=cut



=head2 manualinvoice

  &manualinvoice( $data );

C<$data> is a hashref with the following keys:
C<borrowernumber> is the patron's borrower number.
C<itemnumber> is the item involved, if pertinent;
C<description> is a description of the transaction.
C<$accounttype> may be one of C<FINE>, C<NEWCARD>, C<ACCTMANAGE> or C<SUNDRY>
C<$amount> is the currency value of the fee
C<$operator_id> is the operator id, i.e. the staff member who assessed the fine
C<$branch> is the branch that is issuing the fee

=cut

sub manualinvoice {
    my ( $invoice ) = @_;
    my $dbh      = C4::Context->dbh;
    my ($fee_id, $error);
    
    my %ACCT_TYPES = _get_accounttypes();
    return 'INVALID_ACCOUNT_TYPE' unless($invoice->{accounttype}
                && $ACCT_TYPES{$invoice->{accounttype}}
                && ( $ACCT_TYPES{$invoice->{accounttype}}->{class} eq 'fee' ||
                    $ACCT_TYPES{$invoice->{accounttype}}->{class} eq 'invoice') );
    # clean up data
    if($invoice->{amount} && $invoice->{amount} > 0){
        $invoice->{amount} = Koha::Money->new($invoice->{amount}) unless Check::ISA::obj($invoice->{amount}, 'Koha::Money');
        ( $fee_id, $error ) = _insert_new_fee( $invoice );
    } else {
        $error = "INVALID_INVOICE_AMOUNT";
    }

    return $error // 0;
}

=head2 manualcredit

  &manualcredit( $data, %options );

C<$data> is a hashref with the following keys:
C<borrowernumber> is the patron's borrower number.
C<description> is a description of the transaction.
C<$accounttype> may only be type C<CREDIT>
C<$amount> is the currency value of the credit, as Koha::Money object or as a number.
C<$operator_id> is the staff member's borrowernumber overseeing the transaction.

C<$options{fees}> can optionally specify which fees to apply this credit to.

This function should be called with positive amount values.
The credit will be applied to any outstanding fees, specified
in C<$fees_to_pay> or by chrono order.

Optional:  Specify noapply => 1 to prevent the credits from being automatically linked to fees.
This is just for the upgrade script (converting from accountlines ) and is unlikely to be useful elsewhere.


=cut

sub manualcredit {
    my $credit = shift;
    my %options = @_;
    my $fees_to_pay = $options{fees};
    my $dbh      = C4::Context->dbh;
    my ( $payment, $error );

    my %ACCT_TYPES = _get_accounttypes();
    return 'INVALID_ACCOUNT_TYPE' unless($ACCT_TYPES{$credit->{accounttype}}->{class} eq 'payment');
    # clean up data
    if($credit->{amount} && $credit->{amount} > 0){
        $credit->{amount} = Koha::Money->new($credit->{amount}) unless Check::ISA::obj($credit->{amount}, 'Koha::Money');

        # Ensure that lost items charge separately so they can be individually refunded.
        my $charges = getcharges( $credit->{'borrowernumber'}, 'outstanding' => 1 );
        my $amount_reserved = 0; # If the user selects certain payments over others.
        if ($fees_to_pay && @$fees_to_pay) {
            for my $j (@$charges) {
                if (grep {/$j->{'fee_id'}/} @$fees_to_pay) {
                    $amount_reserved += $j->{'amount'};
                }
            }
        }
        for my $i (@$charges) {
            if ($i->{'accounttype'} eq 'LOSTITEM') { # Only process lost items this way.
                if ( ($fees_to_pay && !@$fees_to_pay) || (grep {/$i->{'fee_id'}/} @$fees_to_pay) ) {
                    if ($credit->{'amount'} >= $i->{'amount'}) {
                        $credit->{'amount'} -= $i->{'amount'};
                        @$fees_to_pay = grep { $_ != $i->{'fee_id'} } @$fees_to_pay;
                        my $payment = { accounttype => 'PAYMENT',
                                        amount => -1 * $i->{'amount'},
                                        description => $i->{'description'}
                        };
                        $error ? ($error .= ApplyCredit($i->{'fee_id'}, $payment)) : ($error = ApplyCredit($i->{'fee_id'}, $payment));
                    }
                }
                elsif ( ($credit->{'amount'} - $amount_reserved) >= $i->{'amount'} ) {
                        $credit->{'amount'} -= $i->{'amount'};
                        my $payment = { accounttype => 'PAYMENT',
                                        amount => -1 * $i->{'amount'},
                                        description => $i->{'description'}
                        };
                        $error ? ($error .= ApplyCredit($i->{'fee_id'}, $payment)) : ($error = ApplyCredit($i->{'fee_id'}, $payment));
                }
            }
        }

        #$credit->{'date'} = ($credit->{'date'}) ? C4::Dates->new($credit->{'date'})->output('timestamp') : C4::Dates->output('timestamp');
        #FIXME: C4::Dates needs updates for above to work.  For now we assume the caller includes a valid date format if it exists.
        $credit->{amount} = -1 * $credit->{amount};  # FIXME : credits are negative, but manualcredit takes positive values.
        if ($credit->{'amount'}) {
            ( $payment, $error ) = _insert_new_payment( $credit );
            RedistributeCredits( $credit->{'borrowernumber'}, $fees_to_pay ) unless($options{noapply});
        }
    } else {
        $error = "INVALID_CREDIT_AMOUNT";
    }
    # TODO: it would probably be useful to return the payment id, or even the full payment hash as well as error.
    return $error // 0;
}



=head2 getcharges

    my $fines = &getcharges($borrowernumber, $options);

Retrieves records from the C<fees> table for the given patron.
Adds the hashkey 'amountoutstanding' to the returned fines hash.
C<$options> can include:

=over 4

=item outstanding => 1 will retrieve only fees that have not been fully paid.

=item since => C<C4::Dates>|TIMESTAMP  will date-limit the results.
    Note since C4::Dates doesn't include time in LK, this is necessarily a >=.
    So to get today's fines, you'd do since=>C4::Dates->new()

=item accounttype => 'code'  limits to fees of a given accounttype.

=item itemnumber => itemnumber   limits to fees on a given item.

=item limit => 10    gets the 10 most recent fines.

=back

Returns an arrayref of fines hashrefs, most recent first.

=cut

sub getcharges {
    my $borrowernumber = shift || return;
    my @bind = ($borrowernumber);

    my %options = @_;
    my $dbh = C4::Context->dbh;
    my $query = qq{
        SELECT * FROM fees
        JOIN fee_transactions AS ft ON(id = fee_id)
        WHERE borrowernumber = ?
            AND accounttype IN (select accounttype from accounttypes where class='fee' or class='invoice')
        };

    if ($options{since}) {
        $query .= " AND timestamp > ? ";
        push @bind, (ref $options{since} eq 'C4::Dates') ? $options{since}->output('iso') : $options{since};
    }

    if($options{itemnumber}) {
        $query .= " AND itemnumber = ? ";
        push @bind, $options{itemnumber};
    }

    if ($options{accounttype}) {
        $query .= " AND accounttype = ? ";
        push @bind, $options{accounttype};
    }

    $query .= " ORDER BY ft.timestamp DESC";

    if ($options{limit}) {
        $query .= " LIMIT ? ";
        push @bind, $options{limit};
    }

    my $sth = $dbh->prepare($query);
    $sth->execute(@bind);

    my @results;
    my $sth_outstanding = $dbh->prepare("SELECT SUM(amount) FROM fees LEFT JOIN fee_transactions ON(fees.id=fee_transactions.fee_id) WHERE fees.id = ?");

    while (my $data = $sth->fetchrow_hashref) {
        $sth_outstanding->execute($data->{fee_id});

        my ($outstanding) = $sth_outstanding->fetchrow_array;

        if ($options{'outstanding'}) {
            next unless($outstanding > 0);
        }

        $data->{'amountoutstanding'} = Koha::Money->new($outstanding);
        $data->{'amount'}            = Koha::Money->new($data->{amount});

        push @results, $data;
    }


    return \@results;
}

=head2 getaccruingcharges

    &getaccruingcharges($borrowernumber);

Gets a list of estimated fees for currently overdue items by borrower.
The fees_accruing table is populated by the fines.pl cron job.

=cut

sub getaccruingcharges {
	my $borrowernumber = shift || return;
	my $dbh        = C4::Context->dbh;
	my $sth = $dbh->prepare(   "SELECT fees_accruing.*, itemnumber, date_due, branchcode
                                FROM fees_accruing
                                    LEFT JOIN issues on ( fees_accruing.issue_id = issues.id )
                                WHERE issues.borrowernumber=?
                                    ORDER BY issuedate" );
	$sth->execute( $borrowernumber );
	my @results;
	while(my $data = $sth->fetchrow_hashref){
	    $data->{'amount'} = Koha::Money->new($data->{amount});
	    push @results,$data;
	}
    return \@results;
}

=head2 getcredits

    my @credits = &getcredits( $fee_id );

Gets a list of credits associated with a given fee,
most recent first.  These are rows from fee_transactions
table, which will show payments, as well as writeoffs & forgivens which are not
stored in the payments table.

options:  payments => 1  will only return payments, not waives.


=cut

sub getcredits {
    my $fee_id = shift;
    my %options = @_;

    my $dbh = C4::Context->dbh;
    my @ptypes = _get_accounttypes('payment');
    my @ttypes = _get_accounttypes('transaction');

    my @accounttypes =  ($options{payments}) ? @ptypes : ( @ptypes, @ttypes );
    my $placeholders = join(',', map {'?'} @accounttypes); # FIXME: this passes in an array with anon hashes every other value.

    my $query = qq{
        SELECT * FROM fee_transactions
        LEFT JOIN payments ON(fee_transactions.payment_id = payments.id)
        WHERE fee_id = ?
        AND accounttype IN ($placeholders)
        ORDER BY timestamp DESC
    };

    my $sth = $dbh->prepare($query);
    $sth->execute($fee_id, @accounttypes);
    my @results;

    while (my $data = $sth->fetchrow_hashref) {
        $data->{'amount'} = Koha::Money->new($data->{amount});
        $data->{date} = $data->{timestamp} unless $data->{date}; # transaction types don't have date.
        push @results, $data;
    }

    return \@results;
}

=head2 gettotalowed

    &gettotalowed($borrowernumber, [$exclude_accruing]);

Gets the total owed for a borrower.
Returns the currency value owed for all outstanding fines by summing every balance-altering
transaction over the history of the account.  Includes accruing fines, unless
$exclude_accruing is passed as true.

=cut

sub gettotalowed {
    my $borrowernumber = shift;
    my $exclude_accruing = shift || 0;
    my $dbh = C4::Context->dbh;
    # Since borrowernumber is stored in fees and payments, not fee_transactions,
    # this is done with two queries: the first gets all outstanding charges, the second
    # picks up any unallocated credits.
    my $sth = $dbh->prepare("SELECT SUM(amount) FROM fees LEFT JOIN fee_transactions on(fees.id = fee_transactions.fee_id) where fees.borrowernumber = ?" );
    $sth->execute( $borrowernumber );
    my ( $amountoutstanding ) = $sth->fetchrow_array;
    $amountoutstanding = Koha::Money->new($amountoutstanding);
    my $sth_credit = $dbh->prepare("SELECT SUM(amount) FROM payments LEFT JOIN fee_transactions on(payments.id = fee_transactions.payment_id) where payments.borrowernumber = ? and fee_id is null" );
    $sth_credit->execute( $borrowernumber );
    my ( $credit ) = $sth_credit->fetchrow_array;
    if ($exclude_accruing) {
        $amountoutstanding += Koha::Money->new($credit);
    } else {
        $amountoutstanding += Koha::Money->new($credit) + gettotalaccruing($borrowernumber);
    }
    return $amountoutstanding ;
}


=head2 gettotalaccruing

    &gettotalaccruing($borrowernumber);

Gets the estimated total of overdue fines for currently checked out items for a borrower.
Relies on population of fees_accruing table by fines.pl cron job.

=cut

sub gettotalaccruing {
    my $borrowernumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT SUM(fees_accruing.amount) FROM fees_accruing JOIN issues on ( fees_accruing.issue_id = issues.id)  WHERE borrowernumber = ?");
    $sth->execute( $borrowernumber );
    my ($data) = $sth->fetchrow_array;
    return Koha::Money->new($data);
}

=head2 getfee

    &getfee($fee_id);

Get information about a Koha fine from the fees and fee_transactions tables, including the amount outstanding

=cut

sub getfee {
    my $fee_id = shift;
    my $dbh = C4::Context->dbh;

    my $query_fee = qq{
        SELECT * FROM fees
        LEFT JOIN fee_transactions ON (fees.id = fee_transactions.fee_id)
        WHERE fees.id = ?
            AND accounttype IN (SELECT accounttype FROM accounttypes WHERE class IN ('fee', 'invoice'))
    };

    my $sth = $dbh->prepare($query_fee);
    $sth->execute($fee_id);
    my $fee = $sth->fetchrow_hashref;
    my $sth_outstanding = $dbh->prepare("select sum(amount) from fees LEFT JOIN fee_transactions on(fees.id=fee_transactions.fee_id) where fees.id = ?");
    $sth_outstanding->execute( $fee_id );
    my ($outstanding) = $sth_outstanding->fetchrow_array;

    $fee->{'amountoutstanding'} = Koha::Money->new($outstanding);
    $fee->{'amount'}            = Koha::Money->new($fee->{amount});

    return $fee;
}

=head2 getpayment

    &getpayment($payment_id, %options);

Get information about a Koha credit from the payments and fee_transactions tables.
Includes rows from payments table, plus associated fee_transactions rows
tucked in arrayref `transactions` and hashref `unallocated`.
There should only be one unallocated row.
%options:
    unallocated => 1  :  limit the returned data to the unallocated portion of the payment. 
    db_lock => 1      :  lock in share mode. use in a transaction if reading for update.
    
=cut

sub getpayment {
    my $payment_id = shift;
    my %options = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM payments JOIN fee_transactions ON(payments.id = fee_transactions.payment_id) WHERE payments.id = ? ";
    $query .=  " AND fee_id IS NULL " if $options{unallocated};
    $query .= " LOCK IN SHARE MODE " if $options{db_lock};
    my $sth = $dbh->prepare($query);
    $sth->execute( $payment_id );
    my $payment_amount => Koha::Money->new();
    my @trans;
    my $unallocated;
    while(my $paytrans = $sth->fetchrow_hashref){
        $paytrans->{amount} = Koha::Money->new($paytrans->{amount});
        if(defined $paytrans->{fee_id}){
            push @trans, $paytrans;        
        } else {
            $unallocated = $paytrans;
        }
        $payment_amount += $paytrans->{amount};
    }
    my $payment = { id              => ($unallocated) ? $unallocated->{id} : $trans[0]->{id},
                    borrowernumber  => ($unallocated) ? $unallocated->{borrowernumber} : $trans[0]->{borrowernumber},
                    description     => ($unallocated) ? $unallocated->{description} : $trans[0]->{description},
                    date            => ($unallocated) ? $unallocated->{date} : $trans[0]->{date},
                    received_by     => ($unallocated) ? $unallocated->{received_by} : $trans[0]->{received_by},
                    accounttype     => ($unallocated) ? $unallocated->{accounttype} : $trans[0]->{accounttype},
                    branchcode     => ($unallocated) ? $unallocated->{branchcode} : $trans[0]->{branchcode},                    
                    unallocated     => $unallocated,
        };
    if(!$options{unallocated}){
        $payment->{amount} = $payment_amount;
        $payment->{transactions} = \@trans;
    }
    return $payment;
}

sub getpayments {
    my $borrowernumber = shift || return;
    my %options = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT id FROM payments WHERE borrowernumber=? ";
    my @bind = ($borrowernumber);
    if($options{since}){
        $query .= " AND date > ? "; # Will behave like >= if C4::Dates object passed (or time-less iso date).
        push @bind, (ref $options{since} eq 'C4::Dates') ? $options{since}->output('iso') : $options{since};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@bind);
    my @all_payments;
    while(my ($id) = $sth->fetchrow){
        push @all_payments, getpayment($id);
    }
    return \@all_payments;

}

# FIXME: arguably, this should be 'can_reverse', and should test things
# like whether any portion of the payment was refunded, etc.
sub is_reversed {
    my $payment = shift;
    # $payment must be from getpayment().
    # There will be only one transaction for a reversed payment.
    if(exists $payment->{transactions}){
        my $fee = getfee($payment->{transactions}->[0]->{fee_id});
        if($payment->{accounttype} eq 'PAYMENT'){
            return $fee->{accounttype} eq 'REVERSED_PAYMENT';            
        } else {
            return $fee->{accounttype} eq 'CANCELCREDIT';                        
        }
    } else {
        return;
    }
}

=head2 reverse_payment


=cut

sub reverse_payment {
    my $id = shift;
    my $dbh = C4::Context->dbh;

    $dbh->begin_work();
    my $payment = getpayment($id, dblock=>1);
    if(is_reversed($payment)){
        $dbh->commit();
        return;
    }
    # Delete all transactions with fee_ids, and update the unallocated amount to the original payment amount.
    # Then add a debit to link to it.
    # FIXME: This duplicates deallocate_payment.
    my $trans_id = (defined $payment->{unallocated}) ? $payment->{unallocated}->{transaction_id} : $payment->{transactions}->[0]->{transaction_id};
    my $sth_del = $dbh->prepare("DELETE FROM fee_transactions WHERE payment_id=? and transaction_id != ?");
    my $sth_up = $dbh->prepare("UPDATE fee_transactions set fee_id=?, amount=? where transaction_id=?");
    my $fee_desc = sprintf("Payment reversed: %s  [%s]", $payment->{description}, C4::Dates->new($payment->{date}, 'iso')->output);
    my $new_fee = { borrowernumber => $payment->{borrowernumber},
                    amount          => -1 * $payment->{amount},
                    accounttype     => ($payment->{accounttype} eq 'PAYMENT') ? 'REVERSED_PAYMENT' : 'CANCELCREDIT',
                    description     => $fee_desc,
    };
    eval{
        my $fee = CreateFee($new_fee, die=>1);
        if(defined $fee){
            $sth_del->execute($id, $trans_id);
            $sth_up->execute($fee->{id},$payment->{amount}->value,$trans_id);
            $dbh->commit();                        
        }        
    };
    if($@){
        $dbh->rollback();
        return $dbh->errstr;           
    }
}


=head2 AddIssuingCharge

&AddIssuingCharge( $issue_id, $charge )

=cut

sub AddIssuingCharge {
    # TODO: Should be by issue_id.
    my ( $itemnumber, $borrowernumber, $charge, $isrenewal ) = @_;
        return unless $charge && $charge > 0;
        $charge = Koha::Money->new($charge) if(Check::ISA::obj($charge, 'Koha::Money'));
        my $desc = ($isrenewal) ? 'Renewal fee' : 'Issuing' ;
        my %new_fee = (
                        borrowernumber => $borrowernumber,
                        itemnumber     => $itemnumber,
                        amount         => $charge,
                        accounttype    => 'RENTAL',
                        );
        my $fee_rowid = CreateFee( \%new_fee );
}


=head2 getaccounttypes

    @list_of_types = &getaccounttypes( $class );
    $hashref_of_types = &getaccounttypes( $class );

In list context, returns a list of all accounttypes of a given category.
accounttype classes include 'fee', 'payment', 'transaction','invoice'.
In scalar context, returns a hashref of accounttypes.

=cut

sub getaccounttypes {
    my %types = _get_accounttypes(shift);
    return wantarray ? keys %types : \%types;
}

=head2

    C4::Accounts::ApplyCredit($fee_id, $action)

Applies a credit to a given fee.
The C<$action> hashref must contain at a minimum

=over 4

=item * $action->{amount}

transaction amount: This is a delta value, i.e. the amount of credit to apply to this fee.
A negative value will decrease the outstanding fee, and will create a payment record for 'PAY' accounttypes.
Positive values will fail, since fees are atomic in Koha.  They should not be increased or edited.
If C<$amount> is omitted, it is assumed the entire amount outstanding on the given fee should be credited.
The following transaction types will ignore C<$action->{amount}> and generate it themselves:
 WRITEOFF, FORGIVE, SYSTEM.
 (you cannot currently write off or forgive a portion of a fine).

=back

C<$action> may specify a transaction or payment accounttype, and any fields in fee_transactions.

Valid transaction accounttypes are:
    FORGIVE, WRITEOFF, LOSTRETURNED, PAYMENT, TRANSBUS, TFORGIVE, SYSTEM

These values are then used to create a new C<fee_transaction> record
(and a payment record if the accounttype is of the 'payment' class).

C<$action> may also be specified as a scalar, just
using the transaction accounttype.  For example, to forgive
a fine, with fee id 789, you may call C<ApplyCredit(789,'FORGIVE');>

Returns dbh error on error.

=cut


sub ApplyCredit {
    my $fee = shift or return;
    my $action = shift;

    my $dbh = C4::Context->dbh;
    # $dbh->{AutoCommit} = 0;  TODO: transaction.

    $fee = getfee($fee) unless ref $fee;
    $action = { accounttype => $action } unless ref $action; # Allow action to be passed in as scalar accounttype.

    $debug and warn "updating fee '$fee->{id}', action: '$action->{accounttype}'";

    my ($new_pmt, $pmt_error, $trans_inserted, $trans_error);
    my $userenv = C4::Context->userenv();

    $action->{operator_id} = $userenv->{number} if ( !defined $action->{operator_id} && $userenv );
    $action->{branchcode}  = $userenv->{branch} if ( !defined $action->{branchcode}  && $userenv );
    $action->{amount}      = Koha::Money->new($action->{amount}) if(defined $action->{amount});

    my $transaction = {
                        fee_id          => $fee->{id},
                        borrowernumber  => $fee->{borrowernumber},
                        operator_id     => $action->{operator_id},
                        branchcode      => $action->{branchcode},
                        accounttype     => $action->{accounttype},
                        notes           => $action->{notes},
                        description     => $action->{description},
                      };

    $transaction->{timestamp} = $transaction->{date} = $action->{date} if $action->{date};
    my $acct_types = getaccounttypes();

    if ($action && $action->{accounttype}) {

        if ( $acct_types->{$action->{accounttype}}->{class} eq 'transaction' ) { # TRANSACTION

            $transaction->{amount} =  (defined $action->{amount}) ? $action->{amount} : (-1 * $fee->{amountoutstanding}) ;

            if ( ($transaction->{amount} >= 0) || ( $transaction->{amount} < (-1 * $fee->{amountoutstanding}) ) ) { # Bad call: positive credit or excess writeoff NOT PERMITTED!
                warn "ApplyCredit [transaction] received a positive credit or excess writeoff: " .
                    "borrower '$fee->{borrowernumber}', fee '$fee->{id}'; " .
                    "attempt to credit amount '$transaction->{amount}' greater than " .
                    "the amount outstanding '$fee->{amountoutstanding}' ";
                return 'INVALID_TRANSACTION_AMOUNT';
            }

            ($trans_inserted, $trans_error) = _insert_fee_transaction($transaction);

            if ($trans_error) {
                warn "Error inserting fee_transaction $trans_error";
                return $trans_error;
            }

        }
        elsif ( $acct_types->{$action->{accounttype}}->{class} eq 'payment' ) { # PAYMENT
            my $pay_amt;

            if ( (!defined $action->{'amount'}) || ($action->{'amount'} == (-1 * $fee->{'amountoutstanding'})) ) { # Full payment
                $pay_amt = (-1 * $fee->{amountoutstanding});
            }
            elsif ( ($action->{amount} < 0) && ($action->{amount} > (-1 * $fee->{'amountoutstanding'})) ) { # Partial payment
                $pay_amt = $action->{amount};
            }
            else { # Bad call: overpayment NOT PERMITTED!
                warn "ApplyCredit [payment] received a positive credit: " .
                    "borrower '$fee->{borrowernumber}', fee '$fee->{id}'; " .
                    "attempt to credit amount '$action->{amount}' greater than " .
                    "the amount outstanding '$fee->{amountoutstanding}' ";
                return 'INVALID_PAYMENT_AMOUNT';
            }

            $transaction->{amount} = $pay_amt;
            ($new_pmt, $pmt_error) = _insert_new_payment($transaction);

            my ($unallocated, $unpaid) = allocate_payment( payment => $new_pmt, fee => $fee ); # Why bother gathering the return values if they arent' used?

        }
        else { # Bad call: $acct_types->{$action->{accounttype}}->{class} NEITHER a 'transaction' nor a 'payment'.
            return 'NO_ACTION_SPECIFIED';
        }

    }
    else { # Bad call: $action && $action->{accounttype} not defined.
        return 'NO_ACTION_SPECIFIED';
    }

    return;
}


=head2 RedistributeCredits

    undef = C4::Accounts::RedistributeCredits( $borrowernumber, \@fees_to_credit );

Splits out or consolidates any unapplied credits to pay down outstanding
fees for a given borrower.  If $fees_to_credit is supplied, these fees will be
credited first, and any remaining credit will be applied to remaining fees in
chronological order (oldest first).

C<$borrowernumber> is the ID of the borrower to act upon.
C<$fees_to_credit> is a listref of fee id's to act upon preferentially.

=cut

sub RedistributeCredits {
    my $borrowernumber = shift or die;
    my $preferred_fees = shift || ();
    my $charges = getcharges( $borrowernumber, 'outstanding' => 1 );
    my @outstanding_fees = sort {$a->{timestamp} cmp $b->{timestamp}} @$charges;
    for(my $i=0;$i<=$#$preferred_fees;$i++){
        my ($fee_index) = grep {$outstanding_fees[$_]->{fee_id} == $preferred_fees->[$i]} 0..$#outstanding_fees;
        if(defined $fee_index){
            $preferred_fees->[$i] = splice(@outstanding_fees, $fee_index,1);
        } else {
            splice(@$preferred_fees, $i,1);
        }
    }
    unshift(@outstanding_fees,@$preferred_fees);
    for my $charge (@outstanding_fees) {
        my ($credit, $payments, $remaining_fee);
        do {
            ($credit, $payments) = get_unallocated_credits( $borrowernumber, reallocable => 1 );
            last if not defined @$payments[0]; # No credits left, so bail
            # we have an unapplied credit and an unpaid fee, so let's match them up
            (undef, $remaining_fee) = allocate_payment( payment => @$payments[0]->{id}, fee => $charge->{'fee_id'} );
        } while ($remaining_fee > 0); # all paid up!
        last if ($credit >= 0); # No credits, so bail
    }
}


=head2 CreateFee

    $row_id = C4::Accounts::CreateFee( $data, die=>0 );

Adds a new fee record based on the data passed in via
the hashref.  The hashref should contain keys that match
columns in the C<fees> table, plus amount & accounttype for the transaction entry.
This is just a wrapper around the internal function _insert_new_fee().

C<$data> is the hash of values to be inserted for the new fee
C<$rowid> returns the row id of the fee inserted

If 'die' option is passed, the fee is created without db transaction,
and will die on failure.  Else will return undef on failure.

=cut

sub CreateFee {
    my $data = shift;
    my %option = @_;
    
    # TODO: sanity checks.
    $data->{'amount'} = Koha::Money->new($data->{amount}) unless(Check::ISA::obj($data->{amount}, 'Koha::Money'));
    my ( $fee, $error ) = _insert_new_fee( $data, die=>$option{die});
    if ( $error ) {
        warn $error;
        warn p $data;
        return;
    }
    return $fee;
}

=head2 _insert_new_fee

    ($fee_id, $error) = _insert_new_fee( \%data, die=>0 );

Inserts a new fee into the C<fees> and C<fee_transactions> tables.

Certain expected values are checked for presence in the hash.  IF not there, they are added for default values

=cut

sub _insert_new_fee {
    my $data = shift;
    my %option = @_;
    
    my $error = '';
    my $insquery = '';
    #FIXME : test for valid values.
    if($data->{amount} <= 0 || ! Check::ISA::obj($data->{amount}, 'Koha::Money')){
        return ( undef, 'INVALID FEE AMOUNT' );
    }
    my $transaction = {
                borrowernumber  => $data->{borrowernumber},
                amount          => $data->{amount},
                accounttype     => $data->{accounttype},
                branchcode      => $data->{branchcode},
    };
    $transaction->{operator_id} = $data->{operator_id} if( defined $data->{operator_id} );
    $transaction->{timestamp} = $data->{timestamp} if( defined $data->{timestamp} );
    $transaction->{notes} = $data->{notes} if( defined $data->{notes} );
    
    my $dbh = C4::Context->dbh;
    $dbh->begin_work() unless $option{die};
    eval {
        my $sth=$dbh->prepare_cached("INSERT INTO fees (borrowernumber,itemnumber,description) VALUES ( ?,?,? )");
        my @bind = ( $data->{'borrowernumber'}, $data->{'itemnumber'} , $data->{'description'} );
        my $rowsinserted = $sth->execute( @bind );
        # FIXME : mysql-specific.
        # add new fee id to data.
        $transaction->{id} = $transaction->{fee_id} = $dbh->{mysql_insertid};
        my ( $trans_row_inserted, $trans_error ) = _insert_fee_transaction( $transaction );
        $dbh->commit() unless $option{die};
    };
    if($@){
        $error.=" ERROR in _insert_new_payment : $@ ";
        warn "Transaction aborted because $@";
        if($option{die}){
            die;
        } else {
            $dbh->rollback;            
        }
    }
    $transaction->{amountoutstanding} = $transaction->{amount};
    return ( $transaction, $error );
}

=head2 _insert_new_payment

    ($payment, $error) = _insert_new_payment( \%data );

Inserts new payment records into C<payments> table.

Expected values like accounttype and date are checked for
existence.  If not present, default values are used.

C<%data> is a hashref of values to use for the payment record.
Should include:

=over 4

=item * accounttype (default: PAYMENT)

=item * borrowernumber

=item * operator_id (optional)

=item * branchcode (optional)

=item * description (optional)

=back

C<$payment> returns the payment and transaction records inserted, including the payment_id. as C<$payment->{id}>
C<$error> is any error messages as a result of the insertion.
It is left to the caller to associate the payment with a specific fee.

=cut

sub _insert_new_payment {
    my $data = shift;
    my $error = '';

    my %ACCT_TYPES = _get_accounttypes();
    # FIXME: Need to port over LAK's Dates module so we can handle timestamps.
#    my $pmt_date = ( defined $data->{date} ) ? C4::Dates->new($data->{'date'},'iso') : C4::Dates->new() ;
    if( defined $data->{accounttype}){
        return( undef, 'INVALID ACCOUNTTYPE' ) unless( $ACCT_TYPES{$data->{accounttype}}->{class} eq 'payment');
    } else {
        $data->{'accounttype'} = 'PAYMENT';
    }
    if($data->{amount} >= 0 || ! Check::ISA::obj($data->{amount}, 'Koha::Money')){
        return ( undef, 'INVALID PAYMENT AMOUNT' );
    }
    my $payment = {
            borrowernumber  => $data->{borrowernumber},
            description     => ($data->{description}) ? $data->{description} : $ACCT_TYPES{$data->{accounttype}}->{description},
            received_by     => $data->{received_by} || $data->{operator_id},
            date            => $data->{date} || undef,
            reallocate      => => $data->{reallocate} // 1
    };
    
    my $txn = {
            accounttype     =>  $data->{accounttype},
            amount          => $data->{amount},
            operator_id     => $data->{operator_id},
            branchcode      => $data->{branchcode},
            notes          => $data->{notes},
        };
    $txn->{timestamp} = $payment->{date} if(defined $payment->{date}); # FIXME: this is just for the upgrade script, or possibly to allow staff to enter payment receipt after it happens.

    my $userenv = C4::Context->userenv();
    if(ref($userenv)){
        $payment->{received_by} = $data->{'received_by'} || $userenv->{'number'};
        $txn->{operator_id} = $data->{'operator_id'} || $userenv->{'number'};
        $txn->{branchcode}  = $data->{'branchcode'} || $userenv->{'branch'};
    }
    my @bind = ( $payment->{'borrowernumber'}, $payment->{'received_by'}, $payment->{'description'}, $payment->{date}, $payment->{reallocate});
    my $dbh = C4::Context->dbh;
    $dbh->begin_work();
    eval {
        my $sth=$dbh->prepare_cached("INSERT INTO payments ( borrowernumber, received_by, description, date, reallocate ) VALUES ( ?, ?, ?, ?, ? )");
        my $rows_inserted = $sth->execute( @bind );
        $payment->{id} = $txn->{payment_id} = $dbh->{mysql_insertid};
        my ($trans_id, $trans_error) = _insert_fee_transaction( $txn );
        $dbh->commit();
        $txn->{'transaction_id'} = $trans_id;
    };
    if($@){
        $error.=" ERROR in _insert_new_payment : $@ ";
        cluck "Transaction aborted because $@";
        warn p $payment;
        $dbh->rollback;
    }
    # To make this interface match that of getpayment():
    # FIXME: This is sloppy; we need better type definition for payment.
    $payment->{unallocated} = $txn;
    return ( $payment, $error );

}

=head2 _insert_fee_transaction

    ($trans_id, $error) = _insert_fee_transaction( \%data );

Inserts a row into C<fee_transaction> a record consisting of values
from the C<%data> hashref.  The only column checked for existence is
the data field.
Note this sub should always be called inside transaction, with $dbh->{RaiseError},
or minimally, within an eval.  

C<%data> is a hashref of column values to use for the fee_transaction
record.
C<$trans_id> returns the transaction_id of the row inserted into the table
C<$error> returns any error messages that result from the table insertion.

=cut

sub _insert_fee_transaction {
    my $data = shift;
    my $error = '';
    my $dbh = C4::Context->dbh;
    
    if( ! $data->{payment_id} && ! $data->{fee_id}){
        die "INVALID TRANSACTION: Not associated to payment or fee.";
    }
    unless( defined($data->{'operator_id'}) &&  defined($data->{'branchcode'}) ){
        my $userenv = C4::Context->userenv();
        if(ref($userenv)){
            $data->{operator_id} = $userenv->{'number'} unless $data->{'operator_id'};
            $data->{branchcode}  = $userenv->{'branch'} unless $data->{'branchcode'};
        }
    }
    my $sth=$dbh->prepare_cached("INSERT INTO fee_transactions ( payment_id, fee_id, accounttype, amount, operator_id, branchcode, notes, timestamp ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ? )");
    my @bind = (    $data->{payment_id},
                    $data->{fee_id},
                    $data->{accounttype},
                    $data->{amount}->value,
                    $data->{operator_id},
                    $data->{branchcode},
                    $data->{notes},
                    $data->{timestamp} || undef
                );
    $sth->execute( @bind );

    if ( $dbh->errstr ) {
        $error.="ERROR in _insert_fee_transaction ".$dbh->errstr;
        warn $error;
    }
    my $trans_id = $dbh->{mysql_insertid};

    return ( $trans_id, $error );
}


=head2 _get_accounttypes

    @types = _get_accounttypes($trans_type);

Returns a hashref of account types, with keys of accounttype code.
There are some accounttypes with special behaviors in Koha; all of
these should be defined in the accounttypes table in a default installation.
At some point, we'll allow the user to add new types, but this is yet unimplemented.
C<$trans_type> is the account class, one of ( 'fee' , 'payment', 'transaction' ).

=cut

sub _seed_accounttypes_cache {
    my $types = C4::Context->dbh->selectall_hashref(
        'SELECT * FROM accounttypes',
        'accounttype');
    for (values %$types) {
        delete $_->{accounttype};
    }
    return $types;
}

sub _get_accounttypes {
    my $trans_type = shift;

    my $cache = C4::Context->getcache(__PACKAGE__,
                                      {driver => 'RawMemory',
                                       datastore => C4::Context->cachehash});
    my $types = $cache->compute('accounttypes', '1h', \&_seed_accounttypes_cache);
    return %$types unless ($trans_type);

    return map {$_ => $types->{$_}} grep {$types->{$_}{class} ~~ $trans_type} keys %$types;
}

=head2 get_unallocated_credits

   ($total_credit, $payments) = get_unallocated_credits( $borrowernumber );

Gets the id and unallocated amounts from the C<payments> table
where the unallocated amount is greater than zero.

C<$borrowernumber> is the borrower id to search on.
C<@payments> is a arrayref of hashrefs of ids and amounts of payments that
have unallocated amounts.

=cut

func get_unallocated_credits($borrowernumber, :$reallocable) {
    my $dbh = C4::Context->dbh;
    my $total_credit = Koha::Money->new();
    my @payment_ids;
    my $credit_select = "SELECT * FROM payments LEFT JOIN fee_transactions on(payments.id = fee_transactions.payment_id) WHERE payments.borrowernumber = ? AND fee_id IS NULL AND amount < 0";
    $credit_select .= " AND reallocate=1" if $reallocable;
    my $sth_credit = $dbh->prepare($credit_select);
    $sth_credit->execute( $borrowernumber );
    my $sth_total = $dbh->prepare("SELECT SUM(amount) FROM payments LEFT JOIN fee_transactions  on(payments.id = fee_transactions.payment_id) WHERE payments.id=?");
    my @payments;
    
    while (my $data = $sth_credit->fetchrow_hashref) {
        #$data->{'date'} = C4::Dates::format_date($data->{'timestamp'}); #wrong.
        $data->{'amount'} = Koha::Money->new($data->{amount});
        # FIXME: For compatibility with C4::Accounts::getpayment, the transaction data should go in the 'unallocated' hashkey instead of a straight join.
        $sth_total->execute($data->{id});
        my ($total) = $sth_total->fetchrow;
        $data->{'payment_amount'} += Koha::Money->new($total);
        push @payments, $data;
        $total_credit += $data->{amount};
    }
    return ( $total_credit, \@payments);
}

=head2 allocate_payment

    ($unallocated, $fee_remaining ) = allocate_payment( payment=>$payment, fee=>$fee [, amount=>$amt, preserve_date=>1 ] );

Takes C<payment> as id or the output of getpayment and C<fee>, as fee_id from a C<fee> record or the C<fee> hashref (from getfee()).
Adjusts the unallocated amount, associating the payment to the fee.

Optional arguments:
amount: amount to allocate.  Fails if this value exceeds the fee amount.
preserve_date: bool, preserve the unallocated's timestamp when adding a new transaction. (probably only useful for upgrade script)

Returns the new unallocated amount from the payment (if the payment was larger than the fee),
and the new total owed on the fee.

=cut

sub allocate_payment {
    my %args = @_;

    if (!$args{payment} || !$args{fee}){
        cluck "FAIL: sub allocate_payment: \$args{payment} = '$args{payment}'; \$args{fee} = '$args{fee}'; full dump of \%args : " . p %args;
        return;
    }

    my $payment = (ref $args{payment}) ? $args{payment} : getpayment($args{payment}, unallocated=>1);
    my $fee = (ref $args{fee}) ? $args{fee} : getfee($args{fee});

    if (!exists $payment->{id} || !exists $fee->{id}){
        warn "WARNING: sub allocate_payment: attempt to allocate payment to fee. \$payment->{id} = '$payment->{id}'; \$fee->{id} = '$fee->{id}'";
    }

    if ( !exists $payment->{unallocated} ) {
        # FIXME: type slop. since we allow $payment to be passed in as a hashref, it
        # might be payments join transactions rather than output of getpayment.
        $payment = getpayment($payment->{id}, unallocated=>1);
    }

    my $unallocated_amt = (Check::ISA::obj($payment->{unallocated}->{amount}, 'Koha::Money')) ? $payment->{unallocated}->{amount} : Koha::Money->new($payment->{unallocated}->{amount});
    my $amt;

    if ( exists $args{amount} ) {
        $amt = (Check::ISA::obj($args{amount}, 'Koha::Money')) ? $args{amount} : Koha::Money->new($args{amount});
        $amt = (-1 * $amt) unless ($amt < 0);

        if ( ($amt < $unallocated_amt) || ($amt < (-1 * $fee->{amountoutstanding})) ) {
            warn "FAIL: sub allocate_payment: attempted OVER allocation of payment: \$amt = '$amt'; \$unallocated_amt = '$unallocated_amt'";
            warn p $payment;
            warn p $fee;
            return $unallocated_amt, $fee->{amountoutstanding};
        }
    }
    else {
        $amt = $unallocated_amt;
    }

    my $preserve_date = exists $args{preserve_date};
    my $dbh = C4::Context->dbh;
    my $remaining_credit = $unallocated_amt;
    my $remaining_fee = $fee->{'amountoutstanding'};

    $amt = max($amt, $remaining_credit, (-1 * $remaining_fee) );

    $debug and warn "Allocating payment $payment->{id}: have $unallocated_amt to apply to $remaining_fee ; applying $amt";

    # FIXME: Rather than doing transaction in this sub, it should die on failure, and
    # callers should do the transactions.
    if ($unallocated_amt == $amt) { # Full allocation of unallocated portion
        $remaining_fee += $amt;
        $remaining_credit -= $amt;
        my $sth_trans = $dbh->prepare_cached("UPDATE fee_transactions set fee_id = ? where transaction_id = ?");
        $sth_trans->execute( $fee->{'id'}, $payment->{unallocated}->{transaction_id} );
    }
    else { # If there is some remaining credit, then we adjust the fee_id = NULL fee_transaction, and we add a new one with this fee_id.
        $remaining_credit -= $amt;
        my $pay_trans = {
            fee_id      => $fee->{id},
            payment_id  => $payment->{id},
            amount      => $amt,
            accounttype => $payment->{unallocated}->{'accounttype'},
            notes       => $payment->{unallocated}->{notes}  # Primarily for upgrade script.
        };
        $pay_trans->{timestamp} = $payment->{unallocated}->{timestamp} if $preserve_date;

        $dbh->begin_work();
        eval {
            my ($trans_id, $trans_error) = _insert_fee_transaction( $pay_trans );
            my $sth_trans = $dbh->prepare_cached("UPDATE fee_transactions set amount = ? where transaction_id = ?");
            my $update_ok = $sth_trans->execute( $remaining_credit->value, $payment->{unallocated}->{transaction_id} );
            $remaining_fee = Koha::Money->new();
            $dbh->commit();
        };
        if ($@) {
            warn "allocate_payment aborted : $@";
            $dbh->rollback;
            $remaining_credit = $unallocated_amt;
            $remaining_fee = $fee->{'amountoutstanding'};
        }
    }

    return ( $remaining_credit, $remaining_fee );
}


func set_reallocate_flag($payment_id, $reallocate){
    my $dbh = C4::Context->dbh;
    $reallocate //= 1;
    my $sth_reallocate = $dbh->prepare("UPDATE payments set reallocate=? where id=?");
    $sth_reallocate->execute($reallocate, $payment_id);
}

=head2 deallocate_payment

    $unallocated = deallocate_payment( payment=>$payment_id [, fee=>$fee, reallocate => 1 ] );

Takes C<payment> as id or hash from getpayment() and optionally C<fee>, as fee_id from a C<fee> record or the C<fee> hashref (from getfee()).
Adjusts the unallocated amount, disassociating the payment from the fee, or from all fees.
Note that if supplying payment as hash, caller MUST call getpayment with dblock=>1 option.

If reallocate option is passed (and falsey), mark the payment as not-to-be auto-reallocated.  [defaults to true]


=cut

sub deallocate_payment {
    my %args = @_;
    # warn " deallocate_payment called with payment id : $args{payment} / fee id : $args{fee}";
    if(!$args{payment}){
        warn "Bad call to deallocate_payment";
        return;
    }
    $args{reallocate} //= 1;
    my $dbh = C4::Context->dbh;
    
    my $fee;
    if( exists $args{fee}){
        $fee = (ref $args{fee}) ? $args{fee} : getfee($args{fee});
    }

    my $sth_del = $dbh->prepare("DELETE FROM fee_transactions where transaction_id=?");
    my $sth_upd = $dbh->prepare("UPDATE fee_transactions set fee_id=NULL, amount=? WHERE transaction_id=?");

    $dbh->begin_work();
    my $payment = getpayment($args{payment}, db_lock=>1);
    if(!exists $payment->{id} || !exists $fee->{id}){
        warn "Attempt to deallocate payment from fee.  One/both don't exist.";
        $dbh->commit();  # just dropping the row lock set in getpayment.
        return;
    }
    eval{
        # If payment is fully allocated, convert first transaction to unallocated, else update unallocated.
        my @transactions = (!$fee) ? @{$payment->{transactions}} : grep { $_->{fee_id} == $fee->{fee_id} } @{$payment->{transactions}};
        my $target_row = (defined $payment->{unallocated}->{id}) ? $payment->{unallocated} : shift @transactions;
        my $total = Koha::Money->new($target_row->{amount});
        for my $trans (@transactions){
            $total += $trans->{amount};
            $sth_del->execute($trans->{transaction_id});
        }
        $sth_upd->execute($total->value,$target_row->{transaction_id});
        $dbh->commit();
        if(!$args{reallocate}){
            set_reallocate_flag($payment->{id},0);
        }
        return $total;     
    };
    if($@){
        warn "deallocate_payment aborted : $@";
        $dbh->rollback;
        return;
    }
}


=head2 chargelostitem

    Charge LOSTITEM fee for an item, and mark that issue returned.
    Caller is responsible for creating the lost item record, which must exist.

=cut

sub chargelostitem{

    my $lost_item_id = shift;

    my %ACCT_TYPES = _get_accounttypes();
    my $dbh = C4::Context->dbh();
    my $sth=$dbh->prepare("SELECT li.borrowernumber,
                                  li.title,
                                  li.homebranch,
                                  li.holdingbranch,
                                  li.itemnumber,
                                  items.itype,
                                  items.onloan,
                                  items.replacementprice,
                                  issues.id AS issue_id,
                                  itemtypes.replacement_price,
                                  borrowers.branchcode AS borrower_branch
                             FROM lost_items li
                                    JOIN items USING(itemnumber)
                                    JOIN itemtypes ON(items.itype=itemtypes.itemtype)
                                    JOIN borrowers USING(borrowernumber)
                                    LEFT JOIN issues ON(issues.borrowernumber=li.borrowernumber AND issues.itemnumber=li.itemnumber)
                            WHERE li.id = ? ");
    $sth->execute($lost_item_id);
    my $lost=$sth->fetchrow_hashref();
    return unless $lost->{borrowernumber};
    my $amount = $lost->{replacementprice} || $lost->{replacement_price} || 0;
    return unless $amount;
    $amount = Koha::Money->new($amount);

    my $accounttype = 'LOSTITEM';
    # note issues.branchcode IS the circControl branch, but we might not have an issue.
    # TODO: store circControl branch  AND issue_id in lost_items.
    my $circControlBranch = C4::Circulation::GetCircControlBranch(
           pickup_branch      => $lost->{holdingbranch},
           item_homebranch    => $lost->{homebranch},
           item_holdingbranch => $lost->{holdingbranch},
           borrower_branch    => $lost->{borrower_branch} );
    my $duedate = C4::Dates->new($lost->{'onloan'},'iso');
    my %new_fee_info = (
        borrowernumber => $lost->{'borrowernumber'},
        amount         => $amount,
        accounttype    => $accounttype,
        branchcode     => $circControlBranch,
        description    => $ACCT_TYPES{$accounttype}->{'description'} . ": $lost->{'title'}, due on " . $duedate->output(),
        itemnumber     => $lost->{itemnumber},
    );
    _insert_new_fee( \%new_fee_info );

    # mark issue returned if checked out.
    # FIXME: we probably shouldn't have a lost item record and an issue record.
    # creation of lost item should probably force a return, or we should just leave it up to the caller.
    if($lost->{issue_id}){
        C4::Circulation::MarkIssueReturned($lost->{'borrowernumber'},$lost->{itemnumber});
    } else {
        # Waive any overdue charges (but only if there was actually a lost item charge)
        if($amount){
            my $overdue_fines = getcharges($lost->{borrowernumber}, itemnumber => $lost->{itemnumber}, accounttype => 'FINE');
            if(@$overdue_fines){
                ApplyCredit( $overdue_fines->[0]->{id}, 'OVERDUE_LOST');
            }
        }
    }

    _sendItemLostNotice($lost);
    
    return;
}

=head2 _sendItemLostNotice

    Extract and parse the ITEM_LOST notice and send it to the message_queue,
    if the notice is in the patron's messaging preferences.

=cut

sub _sendItemLostNotice {
    my $lost = shift;

    # Send lost item notice, if desired
    my $mprefs = C4::Members::Messaging::GetMessagingPreferences( {
        borrowernumber => $lost->{borrowernumber},
        message_name   => 'Item Lost'
    } );

    if ($mprefs->{'transports'}) {
      my $borrower
          = C4::Members::GetMember($lost->{borrowernumber}, 'borrowernumber');
      my $biblio
          = GetBiblioFromItemNumber($lost->{itemnumber})
          or die sprintf "BIBLIONUMBER: %d\n", $lost->{biblionumber};

      my $letter = C4::Letters::getletter( 'circulation', 'ITEM_LOST');
      my $branch_details = GetBranchDetail( $lost->{'branchcode'} );
      my $admin_email_address
          = $branch_details->{'branchemail'} || C4::Context->preference('KohaAdminEmailAddress');

      C4::Letters::parseletter( $letter, 'branches', $lost->{borrower_branch} );
      C4::Letters::parseletter( $letter, 'borrowers', $lost->{borrowernumber} );
      C4::Letters::parseletter( $letter, 'biblio', $biblio->{biblionumber} );
      C4::Letters::parseletter( $letter, 'items', $lost->{itemnumber} );

      C4::Letters::EnqueueLetter( {
          letter                 => $letter,
          borrowernumber         => $borrower->{'borrowernumber'},
          message_transport_type => $mprefs->{'transports'}->[0],
          from_address           => $admin_email_address,
          to_address             => $borrower->{'email'},
      } );
    }
}

=head2 credit_lost_item

formerly FixAccountForLostAndReturned

    &credit_lost_item($lost_item_id, credit => 'CLAIMS_RETURNED', undo => 1);

Credit a patron for a LOSTITEM fee against an item.  Called in C4::Circulation::AddReturn and updateitem.pl

If payments have been made, they are unlinked from the fine.
Waives are left in place, and any remaining amount is waived with accounttype LOSTRETURNED,
unless accounttype is specified with named argument 'credit'.
If 'undo' is specified, this reverses the credit by deleting the associated transactions.

=cut

func credit_lost_item( $lost_item_id, :$credit, :$undo, :$exemptfine ) {
    $credit = 'LOSTRETURNED' if(!$credit || $credit ne 'CLAIMS_RETURNED');

    my $dbh = C4::Context->dbh;
    my $lost_item = C4::LostItems::GetLostItemById($lost_item_id);
    return unless $lost_item; # Don't know who to credit.  fail silently.

    # check for a lost item fee and/or surcharge.
    my $query = "SELECT id FROM fees LEFT JOIN fee_transactions ON fee_id=fees.id
                WHERE borrowernumber = ? AND itemnumber = ? AND accounttype='LOSTITEM'";
    my $sth = $dbh->prepare($query);
    $sth->execute($lost_item->{borrowernumber}, $lost_item->{'itemnumber'});

    # What happens if you lose an item twice?  We forgive both charges.

    if($undo){
        # unforgive all such credits.  Hopefully this shouldn't really happen, but we're only keyed on itemnumber.
        # FIXME: This is shady; no audit trail.  We shouldn't delete from fee_transactions.
        my $sth_waives = $dbh->prepare("DELETE FROM fee_transactions WHERE fee_id=? AND accounttype=?");
        while (my ($fee_id) = $sth->fetchrow) {
            $sth_waives->execute($fee_id, $credit);
        }
        # FIXME: fees need to be keyed to issues to avoid targeting incorrect fee.
        if(C4::Context->preference('ApplyFineWhenLostItemChargeRefunded')){
            # We also must forgive the most recent overdue charges for this item.
            my $sth_odue = $dbh->prepare("SELECT id from fees LEFT JOIN fee_transactions ON fee_id=fees.id
                    WHERE borrowernumber = ? AND itemnumber = ? AND accounttype='FINE' ORDER BY timestamp DESC LIMIT 1");
            $sth_odue->execute($lost_item->{borrowernumber}, $lost_item->{'itemnumber'});
            my ($odue_fine) = $sth_odue->fetchrow;
            if($odue_fine){
                my $sth_payments = $dbh->prepare('SELECT DISTINCT payment_id FROM fee_transactions WHERE fee_id=? AND payment_id IS NOT NULL');
                $sth_payments->execute($odue_fine);
                while (my ($payment_id) = $sth_payments->fetchrow){
                    deallocate_payment(fee=>$odue_fine, payment=>$payment_id);
                }
                #FIXME: 'CLAIMS_RETURNED' isn't the right credit type here; should add a 'cancel-claims-returned'
                ApplyCredit($odue_fine, {  accounttype => $credit });
            }
        }

    } else {
        my $sth_payments = $dbh->prepare('SELECT DISTINCT payment_id FROM fee_transactions WHERE fee_id=? AND payment_id IS NOT NULL');   # AND must be payment type
        #my $credited = Koha::Money->new();
        my $reallocate = !C4::Context->preference('RefundLostReturnedAmount');
        while (my ($fee_id) = $sth->fetchrow) {
            $sth_payments->execute($fee_id);
            while (my ($payment_id) = $sth_payments->fetchrow){
                #$credited += 
                deallocate_payment(fee=>$fee_id, payment=>$payment_id, reallocate=>$reallocate);
            }
            ApplyCredit($fee_id, {  accounttype => $credit });
        }
        if($credit eq 'LOSTRETURNED' && (my $odue = C4::Context->preference('ApplyFineWhenLostItemChargeRefunded')) && !$exemptfine){
            # Only apply fine for actually returned item.
            # Claims-returned items do not get an overdue charge until they are found.

            # Avoid duplicate charges -- lost_items can stay in the lost_items table after being found.
            # LAK has a flag for that, we don't have one here.
            # FIXME: Port flag.  This won't work well since we don't tie the fine to the issue but rather to the itemnumber/borrowernumber .
            my $sth_odue = $dbh->prepare("SELECT id from fees LEFT JOIN fee_transactions ON fee_id=fees.id
                    WHERE borrowernumber = ? AND itemnumber = ? AND accounttype='FINE' ORDER BY timestamp DESC LIMIT 1");
            $sth_odue->execute($lost_item->{borrowernumber}, $lost_item->{'itemnumber'});
            my ($odue_fine) = $sth_odue->fetchrow;
            if(!$odue_fine){
                # FIXME: GetOldIssue gets the last checkout.  In this case we're sure it's the right one,
                # But the issue should be stored by id in lost_items.
                my $old_issue = C4::Circulation::GetOldIssue($lost_item->{itemnumber});
                if(!$old_issue->{borrowernumber}){  # possible patron anonymization
                    $old_issue->{borrowernumber} = $lost_item->{borrowernumber};
                }
 		if(!$old_issue->{branchcode}){  # possible no old_issue
      			$old_issue->{branchcode} = $lost_item->{holdingbranch};
          	}
        	if(!$old_issue->{date_due}){  # possible no old_issue
           		$old_issue->{date_due} = $lost_item->{date_lost};
          	}
                my $returndate = ($odue eq 'DateLost') ? C4::Dates->new($lost_item->{date_lost}, 'iso') : undef;
                C4::Overdues::ApplyFine($old_issue, $returndate);
            }
        }
    }
    return;
}

=head2 prepare_fee_for_display

Modify a fees hash to prepare it for template display.
Note this modifies the hash rather than return a copy of it.

=cut

sub prepare_fee_for_display {
    my $fee = shift;
    if($fee->{'itemnumber'}){
        my $item = GetBiblioFromItemNumber($fee->{'itemnumber'});
        $fee->{'biblionumber'} = $item->{'biblionumber'};
        $fee->{'title'} = $item->{'title'};
        $fee->{'itemtype'} = $item->{'itemtype_description'};
        $fee->{'homebranch'} = $item->{'homebranch'};
        $fee->{'barcode'} = $item->{'barcode'};
        $fee->{'itemcallnumber'} = $item->{'itemcallnumber'};
    }
    $fee->{'date'} = C4::Dates::format_date($fee->{'timestamp'});
    $fee->{'isodate'} = C4::Dates::format_date($fee->{'timestamp'}, 'iso');
    $fee->{'amount'} = sprintf("%.2f",$fee->{'amount'}->value);
    # accruing fees
    # Note accruing fees table is integer math, and we assume 2 decimal places for now.
    if(exists($fee->{'date_due'})){
        $fee->{'accruing'} = 1;
        $fee->{date_due} = C4::Dates::format_date($fee->{date_due});
    } else {
        # accruing fee does not have an accounttype.
        my %ACCT_TYPES = _get_accounttypes();
        $fee->{'accounttype_desc'} = $ACCT_TYPES{$fee->{'accounttype'}}->{'description'};
        $fee->{'amountoutstanding'} = sprintf("%.2f",$fee->{'amountoutstanding'}->value);
        $fee->{'payable'} = 1 if($fee->{'amountoutstanding'} > 0 && $fee->{'accounttype'} ne 'REFUND' && $fee->{'accounttype'} ne 'REVERSED_PAYMENT');
            
        
    }
}

sub get_total_overpaid {
    # FIXME: This is a hack and should be removed.
    # It should not be possible to overpay.
    # i.e. link more credits to a fine than its value.
    # if patron overpays, he should end up with an unallocated payment.
    my $borrowernumber= shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select fee_id, sum(amount) as overpayment
        from fees left join fee_transactions on (fee_id=id) where borrowernumber=? group by fee_id having sum(amount) < 0");
    $sth->execute($borrowernumber);
    my $total = Koha::Money->new();
    while (my $overpayment = $sth->fetchrow_hashref) {
        $total+=$overpayment->{overpayment}
    }
    warn "Overpayment!  borrower $borrowernumber" if $total;
    return $total;
}

# Return sum of non-payment credits to an account since a given date.
# Used only by Unique Management atm. returns a negative Koha::Money object.

sub get_total_waived_amount {
    my $borrowernumber= shift;
    my $since = shift || return;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select sum(amount) as waived from fees 
        join fee_transactions on (fee_id=id)
        join accounttypes using(accounttype)
        where borrowernumber=?
        and accounttypes.class='transaction'
        and timestamp > ? ");
    $sth->execute($borrowernumber, (ref $since eq 'C4::Dates') ? $since->output('iso') : $since);
    my ($total) = $sth->fetchrow;
    return Koha::Money->new($total);  
    
}


# add or mod accounttype (invoice class only).
sub mod_accounttype {
    my $accounttype = shift;
    return 'MISSING_CODE_OR_DESCRIPTION' unless $accounttype->{accounttype} && $accounttype->{description};
    return 'INVALID_AMOUNT' if(exists $accounttype->{default_amt} && $accounttype->{default_amt} < 0);
    # Later we'll allow modifying descriptions on payment & fee classes, and probably add a 'credit' class for manual credit types.
    my %acct_types = _get_accounttypes();
    my %invoice_types = _get_accounttypes('invoice');
    my $sth;
    my $dbh = C4::Context->dbh;

    # ok, this is sloppy... we should probably limit chars in this field to a single case.
    if(grep { lc($accounttype->{accounttype}) eq lc($_) } keys %invoice_types){
        #Update
        $sth = $dbh->prepare("UPDATE accounttypes set description=?, default_amt=? WHERE accounttype=? AND class='invoice'");
    } else {
        #Create
        if(grep { lc($accounttype->{accounttype}) eq lc($_) } keys %acct_types){
            return 'DUPLICATE_ACCOUNTTYPE';
        }        
        $sth = $dbh->prepare("INSERT INTO accounttypes (description,default_amt,accounttype,class) VALUES (?,?,?,'invoice')");
    }

    my $def_amt = (Check::ISA::obj( $accounttype->{default_amt}, 'Koha::Money')) ? $accounttype->{default_amt}->value : $accounttype->{default_amt};
    $sth->execute($accounttype->{description}, $def_amt, $accounttype->{accounttype});
    my $cache = C4::Context->getcache(__PACKAGE__,
                                      {driver => 'RawMemory',
                                       datastore => C4::Context->cachehash});
    $cache->remove('accounttypes');                 
    return $dbh->errstr;
}

sub del_accounttype {
    my $accounttype = shift;
    $accounttype = $accounttype->{accounttype} if ref $accounttype;
    return 'ACCOUNTTYPE_NOT_SPECIFIED' unless $accounttype;
    my %invoice_types = _get_accounttypes('invoice');
    if(! exists $invoice_types{$accounttype}){
        return 'INVALID_ACCOUNTTYPE_CLASS';
    }
    my $dbh = C4::Context->dbh;
    my $sth_test = $dbh->prepare("SELECT transaction_id FROM fee_transactions WHERE accounttype=? LIMIT 1");
    $sth_test->execute($accounttype);
    if($sth_test->fetchrow){
        return 'IN_USE';
    } else {
        my $sth_del = $dbh->prepare("DELETE FROM accounttypes where accounttype=? AND class='invoice'");
        $sth_del->execute($accounttype);        
    }
    my $cache = C4::Context->getcache(__PACKAGE__,
                                      {driver => 'RawMemory',
                                       datastore => C4::Context->cachehash});
    $cache->remove('accounttypes');
    return $dbh->errstr;
}

sub can_del_accounttype {
    my $accounttype = shift;
    $accounttype = $accounttype->{accounttype} if ref $accounttype;
    my %invoice_types = _get_accounttypes('invoice');
    return if(!exists $invoice_types{$accounttype});
    my $dbh = C4::Context->dbh;
    my $sth_test = $dbh->prepare("SELECT transaction_id FROM fee_transactions WHERE accounttype=? LIMIT 1");
    $sth_test->execute($accounttype);
    if($sth_test->fetchrow){
        return;
    } else {
        return 1;
    }    
}

=head2 get_borrowers_with_fines

    C4::Accounts::get_borrowers_with_fines( category => 'ADULT', branch => 'MAIN', threshold => 15.00, exclude_notified=>1, since=>365 );

Returns a list of borrower hashes with an additional 'balance' hashkey,
optionally limited by category and/or branch.  If C<since> is provided, ignore
any patrons whose most recent fine is older than C<$since> days old.


=cut

sub get_borrowers_with_fines {
    # returns patron records with fines.
    # available parameters:  category, threshold, branch.
    # FIXME: This should arguably be in C4::Borrowers since it returns borrower-ish data.  It's messy either way.
    # FIXME: The code that this replaces ignored  fees related to debt collect.

    my %param = @_;
    my $dbh = C4::Context->dbh;
    
    #Sadly we must get all patrons, then test amounts since we have to look
    # at fees, unallocated payments and estimated fees.
    # Arguably it might be worth selecting distinct borrowers on fees and on fees_accruing.
    
    my $threshold = $param{'threshold'} // 0;
    my @limits;
    my @limit_substr;
    my $query = "SELECT * from borrowers ";
    if($param{'category'}){
        push @limit_substr, " borrowers.categorycode = ? ";
        push @limits, $param{'category'};
    }
    if($param{'branch'}){
        push @limit_substr, ' borrowers.branchcode = ? ';
        push @limits, $param{'branch'};
    }
    if($param{exclude_notified}){
        push @limit_substr, ' borrowers.amount_notify_date IS NULL '
    }
    my $limit_clause = (scalar @limit_substr) ? " WHERE " . join(' AND ',@limit_substr) : '';
    
    my $sth = $dbh->prepare($query . $limit_clause);
    $sth->execute(@limits);

    my $sth_lastfine = $dbh->prepare("SELECT timestamp FROM fees JOIN fee_transactions ON(fees.id=fee_id) WHERE payment_id IS NULL 
                                        AND borrowernumber = ? 
                                        AND accounttype IN (SELECT accounttype FROM accounttypes WHERE class='fee' OR class='invoice')
                                        ORDER BY timestamp DESC LIMIT 1");
    my $sth_lastaccrual = $dbh->prepare("SELECT fees_accruing.timestamp FROM fees_accruing JOIN issues on ( fees_accruing.issue_id = issues.id)
                                            WHERE borrowernumber = ? ORDER BY fees_accruing.timestamp DESC LIMIT 1");
    
    my @borrowers;
    while (my $bor = $sth->fetchrow_hashref) {
        $bor->{balance} = gettotalowed($bor->{borrowernumber},$param{exclude_accruing});
        next if($bor->{balance} == 0 || $bor->{balance} < $threshold);
        if($param{since}){
            $sth_lastfine->execute($bor->{borrowernumber});
            $sth_lastaccrual->execute($bor->{borrowernumber});
            my ($lastfine_date) = $sth_lastfine->fetchrow;
            my ($lastaccrual_date) = $sth_lastaccrual->fetchrow;
            $lastfine_date = List::Util::maxstr($lastaccrual_date // '',$lastfine_date // '');
            my ($y,$m,$d) = $lastfine_date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
            next if(Date::Calc::Date_to_Days(Date::Calc::Today()) - Date::Calc::Date_to_Days($y,$m,$d) >$param{since});                
        }
        push @borrowers, $bor;
    }

    return \@borrowers;
}



END { }    # module clean-up code here (global destructor)
1;
__END__

=head1 SEE ALSO

DBI(3)

=cut

