#!/usr/bin/env perl

# Part of the Koha Library Software www.koha.org
# Copyright 2009 LibLime
# Licensed under the GPL.

use strict;
use warnings;

# CPAN modules
use DBI;
use Getopt::Long;
use Koha::Money;
use List::Util qw[min max reduce];
use Parallel::ForkManager;

use DDP filters => {
            'DateTime'      => sub { $_[0]->ymd },
            'Koha::Money'   => sub { $_[0]->value } };
            
# Koha modules
use Koha;
use C4::Context;
use C4::Items;
use C4::Circulation;
use C4::Accounts;
use C4::Debug;


my $dbh = C4::Context->dbh;
my $help;
my $verbose;
my $logfile = 'fees_update.log';
my $clear;
my $bno;
my $from;
my $confirm;
my $limit;
my $die;
my $exit = 0;
my $workers = 1;
my $actionlogs = 'action_logs'; # table to look in to recover clobbered fines. (zeroed-out by some bug)
my $workerlog;

$SIG{'INT'} = sub { print "Exiting...\n"; $exit=1; return; };

GetOptions(
    'h|help|?'  => \$help,
    'v|verbose' => \$verbose,
    'output:s'  => \$logfile,
    'clear'     => \$clear,
    'b:i'       => \$bno,
    'die'       => \$die,
    'from:i'    => \$from,
    'c|confirm' => \$confirm,
    'limit:i'   => \$limit,
    'actionlogs:s' => \$actionlogs,
    'w|workers:i'  => \$workers,
    'wlog'      => \$workerlog,

    );

my $num_bor_handled = 0;

# no warnings qw(uninitialized);

my $usage = << 'USAGE';

   Upgrade to new accounting system,
   populating fees, fee_transactions and payments tables.
   This script leaves data in the accountlines table for reference.

This script has the following parameters :
    -output             : path to log output
    -h | --help         : this message
    -v | --verbose      : be verbose.  Set to > 1 for debugging output.
    -b                  : single borrowernumber to update (entire db is done without this param)
    -from               : starting borrowernumber
    -limit              : only to this many patrons
    -die                : die on failures
    -clear              : clear the fees tables before going.  If you run this script twice without this flag, you'll get duplicate fines.
    -actionlogs         : table name of action_logs table, used to recover corrupted fines data
    -confirm            : actually do it.  For safety's sake, this arg is required.
    -w | -workers       : number of workers to use.
    -wlog               : log each borrowernumber to a worker log.  Useful with --die (or if it dies without it) to identify which borrower caused failure and where to restart.

USAGE

die $usage if($help || !$confirm);

if($workers > 1 && $bno){
    die "Can't use multiple workers on one patron.";
} elsif($workers > 1 && $verbose){
    die "You won't be able to make sense of the verbose output with multiple workers.";
}

open LOG, ">$logfile" or die "Can't open $logfile";
print LOG "borrowernumber\tamount\tissue\n";
close LOG;

my %x = (
        A    => 'ACCTMANAGE',  # amt > 0, out >= 0 | manual invoice. may have been paid
        C    => 'CREDIT',      # amt < 0, out < 0  | These are manual credits of type 'credit' (note possibility of amt>0 (rare) )
        CR   => 'CREDIT',      # "
        F    => 'FINE',        # amt > 0, out >= 0 | Overdue fine OR manual invoice. (possible amt<0 from interface bug).
        FFOR => 'FORGIVE',     # amt > 0, out = 0  | These were forgiven fines, formerly some other accounttype, but set to FFOR in 'pay fines' interface..
        FOR  => 'FORGIVE',     # amt < 0, out < 0  | These are manual credits of type 'forgiven'.
        FU   => 'FINE',   # amt > 0, out >= 0 |  * These are still accruing; should check if there's still an issue for it, if not becomes FINE, if so ( or if it's been resolved), just delete it.
        IP   => 'LOSTITEM',    # amt > 0, out >= 0 | equiv to 'L'.
        L    => 'LOSTITEM',    
        LR   => 'LOSTITEM',    # amt > 0.  RARE.  Should be a fine, usually paid, probably from data migration.
        M    => 'SUNDRY',      # amt > 0, out >= 0 | fee.
        N    => 'NEWCARD',     # "
        Pay  => 'PAYMENT',     # amt < 0, out = 0 | Paid.  should be able to link to fine by timestamp.
        PAY  => 'PAYMENT',     # rare.  may be > 0.  treat as credit.
        REF  => 'REFUND',      # amt > 0, out = 0 | treat as REFUND.
        Rent => 'RENTAL',      # amt > 0, out >= 0 | 
        W    => 'WRITEOFF',     # amt > 0, out = 0 && itemnumber || amt < 0, out = 0 (manual credit).
        RCR  => 'CREDIT',
	OLD  => 'REFUND',   # refunds via manual invoice

        );
    # Notes:  'F' in some upgraded Koha installs may represent either 'FINE' OR 'FORGIVE'.
    # Any accounttypes not included in above hash shall be placed into 'SUNDRY'
    # LK fines updates allowed for authorised values for manual invoice types.
    # These authvals were truncated to 5 chars and stored as accounttype (really.)
    # We need to add an interface to define invoice and payment types, but we don't have one yet.  So they'll go to SUNDRY,
    # The authval should still be in the description.

# because it's easy to forget to pass an install-specific param...
my $actionlogs_map = { 'pioneer consortium' => 'archive_action_logs', };

if($actionlogs eq 'actionlogs'){
    $actionlogs = $actionlogs_map->{lc(C4::Context->preference('LibraryName'))} // 'action_logs';
}
eval{
    my $actionlogs_test = $dbh->do("SELECT action FROM $actionlogs limit 1"); # crash if bad tablename given.
};
if($@){
    $actionlogs = 'action_logs';
    warn "Falling back to $actionlogs table";
}

my $sth_logindex = $dbh->prepare("SHOW INDEXES in $actionlogs WHERE key_name='fineslog'");
$sth_logindex->execute();

my ($indextest) = $sth_logindex->fetchrow_array();
unless($indextest){
    warn "Adding action_logs index.";
    $dbh->do("ALTER TABLE $actionlogs ADD INDEX fineslog (module(5),object,timestamp)");
}


if($clear && $bno){
    $dbh->do("DELETE FROM fees WHERE borrowernumber = $bno");
    $dbh->do("DELETE FROM payments WHERE borrowernumber = $bno");
} elsif($clear && $from){
    $dbh->do("DELETE FROM fees WHERE borrowernumber >= $from");
    $dbh->do("DELETE FROM payments WHERE borrowernumber >= $from");        
} elsif($clear){
    $dbh->do("DELETE FROM fees");
    $dbh->do("DELETE FROM payments");
    $dbh->do("DELETE FROM accounttypes where class='invoice' and accounttype <> 'SUNDRY'"); #We keep this invoice type for unidentified fee types.
}


my @protected_accounttypes = (keys %x, values %x);
my $sth_accttype = $dbh->prepare('SELECT * FROM authorised_values where category="MANUAL_INV"');
my $sth_invoice_type = $dbh->prepare("INSERT IGNORE INTO accounttypes (accounttype,description,class,default_amt) VALUES (?,?,'invoice',?)");
$sth_accttype->execute();
while ( my $row = $sth_accttype->fetchrow_hashref() ) {
    my $short_accttype = substr($row->{authorised_value},0,5);
    $short_accttype =~ s/\s*$//;
    if(grep(/$short_accttype/, @protected_accounttypes)){
        die "Use of protected accounttypes in manual_invoice authvals: $short_accttype";
    }
    my $invoice_accttype = substr($row->{authorised_value},0,16);
    $invoice_accttype =~ s/^\s+|\s+$//g;
    $sth_invoice_type->execute($invoice_accttype,$row->{authorised_value},$row->{lib} );
    if(exists $x{$short_accttype}){
        if(ref $x{$short_accttype}){
            push @{$x{$short_accttype}}, $invoice_accttype;
        } else {
            $x{$short_accttype} = [ $x{$short_accttype}, $invoice_accttype ]
        }
    } else {
        $x{$short_accttype} = $invoice_accttype;            
    }
    # ^^ will need to grep accountline description when array.
}

sub get_fine_accttype {
    my $fine = shift;
    my $shortcode = $fine->{accounttype};
    if(ref $x{$shortcode}){
        for (@{$x{$shortcode}}) {
            return $_ if $fine->{description} =~ /\Q$_\E/;
        }
        # it might not be in the description anyway, since staff can edit it prior to adding.
        return $x{$shortcode}[0];
    } else {
        return $x{$shortcode};
    }
}

sub appendLog {
    my $message = shift;
    open FILE, "+>>", $logfile or die "$!";
    flock(FILE, Fcntl::LOCK_EX) or die "$!";
    print FILE $message;
    close FILE;
    return;
}

my %ACCT_TYPES = C4::Accounts::_get_accounttypes();


my $discrepancies = 0; # not using this anymore since we're forking.

my $start_run = time();

my @forks;
my $forker = Parallel::ForkManager->new( $workers );
$forker->run_on_finish(
    sub { my ($pid, $exit_code, $ident) = @_; 
            $verbose and warn "finished with worker $ident -- exited with $exit_code on pid $pid";
            if($exit_code){
                kill 2, grep { $_ != $pid } @forks; # If any worker exited prematurely, kill all of them.
            }
    }
);

for (0..$workers-1) {
    my $pid = $forker->start($_);
    if($pid){
        push @forks, $pid;
        next;
    }

    my $dbh = $C4::Context::context->{dbh} = C4::Context->dbh->clone;
    my $handled = do_patron($dbh, $_);
    printf "Worker $_ handled $handled patrons.\n";
    $forker->finish($exit);
}
$forker->wait_all_children;

my $end_run = time();
printf "Processed above patrons in %s seconds.\n\n", $end_run - $start_run;

exit 0;

sub do_patron{
    my $dbh = shift;
    my $worker_id = shift;
    my $sth_issue = $dbh->prepare("SELECT * from issues where borrowernumber=? and itemnumber=?");
    my $sth_actionlogs = $dbh->prepare("SELECT * FROM $actionlogs WHERE module='fines' AND object=? AND timestamp BETWEEN ? AND ? order by action_id desc");
    my $query;
    if($bno){
        $query = "SELECT DISTINCT borrowernumber FROM archive_accountlines WHERE borrowernumber = $bno";
    } elsif($from){
        $query = "SELECT DISTINCT borrowernumber FROM archive_accountlines WHERE borrowernumber >=$from";
        $query .= " AND borrowernumber % $workers = $worker_id " if($workers > 1);
    } else {
        $query = "SELECT DISTINCT borrowernumber FROM archive_accountlines ";
        $query .= " WHERE borrowernumber % $workers = $worker_id " if($workers > 1);
    }
    $query .= sprintf("LIMIT %d", $limit / $workers) if $limit;
    my $sth = $dbh->prepare($query);
    $sth->execute();
    open WLOG, '>', "worker$worker_id.log" if $workerlog;
    while(my ($borrowernumber) = $sth->fetchrow_array){
    print WLOG " $borrowernumber\n" if $workerlog;
        my @logoutput;
        my $sth2 = $dbh->prepare("SELECT * FROM archive_accountlines where borrowernumber=? ");
        $sth2->execute($borrowernumber);
        my $balance = Koha::Money->new();
        my %paidfines = ();
        my %linked_writeoffs = ();
        my %unlinked_writeoffs = ();
        my %payments = ();
        my %reversed_payments = ();
        my %credits = ();  # 
        my %debits = ();   # 
        my %unknown = ();
        my %zeroed_fines;
        my %refunded_rcrs;
        my %refunds;
        my %rcrs;
        my @acctnos;
        my $has_discrepancy = 0;
        $verbose and warn "Borrowernumber: $borrowernumber \n";
        while (my $a = $sth2->fetchrow_hashref){
            # skip any entries that did not charge an amount.
            #next unless( $a->{amount} || $a->{amountoutstanding} );  # This is imperfect, since we'll lose some data for status changes (eg set to LOST).

            $a->{amountoutstanding} = Koha::Money->new(sprintf("%.2f",$a->{amountoutstanding}));
            $a->{amount} = Koha::Money->new(sprintf("%.2f",$a->{amount}));  # manualinvoice/credit allowed arbitrary precision values...

            if($a->{amount} == 0 && $a->{amountoutstanding} >= 0 && $a->{accounttype} =~ /^FU?$/ ){
                # zeroed amount bug, summer 2011.
                $zeroed_fines{$a->{accountno}} = $a;
                next;
            }

            # FU accounttype should indicate a still-updating fine.
            # We will drop any that don't have an itemnumber and an entry in the issues table.
            # Those that aren't in issues we'll shift to Fine.
            if($a->{accounttype} eq 'FU' && $a->{amount} == $a->{amountoutstanding}){
                $sth_issue->execute($borrowernumber, $a->{itemnumber});
                # if still on issue, hopefully we can ignore the fine
                next if($sth_issue->fetchrow());
            }
            # BUG causes duplicate accountno's.
            # We will ignore these, but adjust balance accordingly.
            my $duplicate_accountnos;
            if( $a->{accountno} ~~ @acctnos ){
                $duplicate_accountnos = 1;
                if($a->{amountoutstanding}){
                    push @logoutput,  "$borrowernumber\t$a->{amountoutstanding}\tDuplicate accountno encountered.  Total balance altered.\n";
                    $has_discrepancy=1;
                }
            } else {
                push @acctnos, $a->{accountno};
                $balance += $a->{amountoutstanding};            
            }
            if( $a->{amountoutstanding} < 0 && $a->{amount} <= 0){ # some zero-amount fines are actually credits from migration.
                $credits{$a->{accountno}} = $a;
                next;                
            }
  
            if($a->{amountoutstanding} > $a->{amount} && $a->{description} ~~ /\(Reversed\)/){

                #If the amountoutstanding on the reversed payment is zero, then the reversal was either reversed or paid.
                # This is because a reversed payment becomes a debit, and so can be paid.  
                # If it was paid, the reversed payment line's description is copied into the payment line,
                # which makes it look like the payment on the reversed payment was also reversed when in fact it wasn't.
                # Concatenating strings to the description column was a terrible idea.
                # 
                # This should be handled such that the original fee is paid by the second payment.  We won't bother linking them though; after
                # handling all the fully paid fees, the payment on the reversed payment will be distributed by date.
                # This will usually be correct.

                $reversed_payments{$a->{accountno}} = $a;
                # $a->{description} ~~ /Payment for no.(\d+)/;
                # if(defined $1){     }
                delete $debits{$a->{accountno}};
                next;
            }
            if($a->{amountoutstanding} == 0 && $a->{description} ~~ /adjusted to no longer overdue/){
                # Not a real fine.  drop it.
                next;
            }
            if( ($a->{amountoutstanding} > 0 && $a->{amountoutstanding} == $a->{amount})                # i.e. unpaid fines.
                 || ($a->{amountoutstanding} > 0 && $a->{amount} == 0 && $a->{accounttype} eq 'FU')     #  a bug, where there's a 0 amount.
                 || ($a->{amountoutstanding} > 0 && $a->{amount} == 0 && $a->{accounttype} eq 'F')      # migration issue.
                 || ($a->{amountoutstanding} > 0 && $a->{amount} < $a->{amountoutstanding} )            # migration, and some 'PTFS UPGRADE' entries.
                 ){   
                
                $debits{$a->{accountno}} = $a;
                next;
            }
            if(($a->{amount} > 0 && $a->{amountoutstanding} < $a->{amount} && $a->{accounttype} ne 'W') 
                || ($a->{amount} >= 0 && $a->{amountoutstanding} < 0 && ($a->{accounttype} eq 'F' || $a->{accounttype} eq 'FU')) ){
                $paidfines{$a->{accountno}} = $a;
                next;
                # The second conditional is for an odd case where we end up with a credit,
                # seemingly from data migration, or possibly from community code.
            }
            ## WARNING: Before Ha's work, writeoffs were stored as positive amounts.
            # I'm not sure if these will be correct for all cases:
            $linked_writeoffs{$a->{accountno}} = $a if( $a->{amountoutstanding} == 0 && $a->{amount} < 0 && $a->{itemnumber} && $a->{accounttype} eq 'W');
            $unlinked_writeoffs{$a->{accountno}} = $a if( $a->{amountoutstanding} == 0 && $a->{amount} < 0 && ! $a->{itemnumber} && $a->{accounttype} eq 'W');
            
            if($a->{amountoutstanding} == 0 && $a->{amount} < 0 && $a->{accounttype} eq 'REF'){
                $refunds{$a->{accountno}} = $a;
                next;
            }
            if($a->{amountoutstanding} == 0 && $a->{amount} < 0 && $a->{accounttype} eq 'CR'){
                $refunded_rcrs{$a->{accountno}} = $a;
                next;
            }
            if($a->{amountoutstanding} == 0 && $a->{amount} < 0 && $a->{accounttype} eq 'RCR'){
                $rcrs{$a->{accountno}} = $a;
                next;
            }
            $a->{allocated} = Koha::Money->new(0); # For payments, we'll track allocated amount as they're linked to fees.
            $payments{$a->{accountno}} = $a if( $a->{amountoutstanding} == 0 && $a->{amount} < 0 && $a->{accounttype} ne 'W');
        }

        $verbose and warn "\tPaidfines: ".scalar(keys %paidfines) .
                        "\n\tlinked writeoffs: ".scalar(keys %linked_writeoffs).
                        "\n\tunlinked writeoffs: ".scalar(keys %unlinked_writeoffs).
                        "\n\tallocateded payments: ".scalar(keys %payments).
                        "\n\toutstanding debits: ".scalar(keys %debits)."\n\toutstanding credits: ".scalar(keys %credits)."\n\tBALANCE: $balance";

        # RCR's: Those that are still owed, are in %credit.
        # Those that have been refunded are in %refunded_rcrs.
        # Those in %rcr's have been 'paid' against another credit.
        # this means its value is applied to that payment, so we'll alter those payments (which may have been reversed).
        if(scalar keys %rcrs){
            $verbose and warn "Handling RCR's converted to payments.";
            for my $f (keys %rcrs){
                my $payline = $rcrs{$f}->{description} =~ / paid at no\.(\d+) /;
                if($payline){
                    $payline = $1;
                    if(exists $payments{$payline}){
                        $verbose and warn "Incrementing payment $payline by $rcrs{$f}->{amount}";
                        $payments{$payline}->{amount} += $rcrs{$f}->{amount};
                        delete $rcrs{$f};                        
                    } elsif(exists $reversed_payments{$payline}) {
                        # This is probably going to screw up the balance, but the implementation of reversed payments allowed
                        # for this.  Perhaps we should just create a new payment here.  
                        # FIXME: Seems to be wrong.  Need to spend more time here.
                        
                        $reversed_payments{$payline}->{amount} += $rcrs{$f}->{amount};
                        delete $rcrs{$f};  
                      #  $payments{$f} = $rcrs{$f};
                      #  $payments{$f}->{accounttype} = 'CR';                       
                    } else {
                        push @logoutput,  "$borrowernumber\t$rcrs{$f}->{amount}\tUnlinked payment line $payline for RCR\n";
                    }
                    
                } else {
              #      die "Couldn't find matching payment. rcr accountno $f, pay accountno $payline";
                    # there was some code that didn't put the 'paid at no.' in the desc.
                    # transfer these to payments, make them behave like any other credit.
                    $payments{$f} = $rcrs{$f};
                    $payments{$f}->{allocated} = Koha::Money->new(0);
                    $payments{$f}->{accounttype} = 'CR';
                }
            }
        }

        # First take care of reversed payments.
        # Note a reversed payment can be reversed, resulting in a negative amount and a zero amountoutstanding.
        for my $f (keys(%reversed_payments)){
            # When a payment is reversed, the amountoutstanding on the original fine is zeroed and the
            # reversed payment in effect becomes the new fine, which may be paid on yet another line.
            # This hash also holds payments on those fines, so we pass over those here,
            # and instead put them into the credits hash  They can be recognized by ending in "Thanks (-staffid)".
            # They will then later be applied to fees by date.
            if( $reversed_payments{$f}->{description} ~~ /, Thanks \(\-\S+\)$/ ){
                # This is actually a payment against a reversed payment.
                $payments{$f} = $reversed_payments{$f};
                $payments{$f}->{allocated} = Koha::Money->new(0);
                delete $reversed_payments{$f};
                $verbose and warn "Found paid reversed payment at line $f";
            } else {
                $verbose and warn "Found REVERSED_PAYMENT at $f :: \n" . p $reversed_payments{$f};
                # It's actually a reversed payment.
                # We create a fee of accounttype 'REVERSED_PAYMENT' and link.
                # It's not clear if we should keep the itemnumber link here.
                # Reversing a fine in the new fines structure will do no such thing, I think.
                
                my $fine = {    borrowernumber  => $reversed_payments{$f}->{borrowernumber},
                                itemnumber      => $reversed_payments{$f}->{itemnumber},
                                amount          => -1 * $reversed_payments{$f}->{amount},
                                timestamp       => $reversed_payments{$f}->{date},
                                description     => $reversed_payments{$f}->{description},
                                accounttype     => 'REVERSED_PAYMENT',
                                notes           => sprintf("accountno:%d",$f),
                };
                $fine->{branchcode} =  $reversed_payments{$f}->{branchcode} if($reversed_payments{$f}->{branchcode});            
                my ($fee, $error) = C4::Accounts::_insert_new_fee($fine);
                $verbose and warn " Created FEE for REVERSED_PAYMENT as fee_id: $fee->{id}";
                my $trans = {  accounttype => 'PAYMENT',
                            date   => $reversed_payments{$f}->{date}, # We don't actually know the date since date is the payment date and timestamp can be updated later.
                            description => $reversed_payments{$f}->{description},
                            notes       => sprintf("accountno:%d",$f),
                         };
                C4::Accounts::ApplyCredit( $fee , $trans );
                $reversed_payments{$f}->{description} =~ /^Payment for no.(\d+)/;
                if(defined $1){
                    # get rid of the "paid at" string in the original fine's description, since it is no longer paid (at least here)
                    my $orig_fine = $paidfines{$1} || $debits{$1};
                    my $paydate = C4::Dates->new($reversed_payments{$f}->{date},'iso')->output();
                    $orig_fine->{description} =~ s/(, )?paid at no.$f $paydate//;
                }
            }

        }
        
        # Now, try to recover zeroed fines from action_logs.
        # we do it by date to try to match those without itemnumbers.
        my %datemap;
        push @{$datemap{$_->{date}}->{acctlines}}, $_ for values %zeroed_fines;
        for my $date (keys %datemap){
            $sth_actionlogs->execute($borrowernumber, $date, "$date 23:59:59");
            $datemap{$date}->{logs} = $sth_actionlogs->fetchall_arrayref({ info=>1, action=>1 });
            next unless scalar @{$datemap{$date}->{logs}}; # no logs; these will end up discarded.
            my %fine_amount;
            for my $logrow (@{$datemap{$date}->{logs}}){
                # get the first non-zero amount for this itemnumber. ( we should find a zero first for when it was set to zero )
                my ($amount,$itemnumber) = $logrow->{info} =~ /amount=(\d+\.?\d*) itemnumber=(\d+)$/ ;
                next if( !defined $amount || $amount == 0 || $fine_amount{$itemnumber});
                $fine_amount{$itemnumber} = $amount;
            }
            my @sans_itemnumber;
            for my $acctline (@{$datemap{$date}->{acctlines}}){
                if(!$acctline->{itemnumber}){
                    push @sans_itemnumber, $acctline;
                    next;
                }
                if($fine_amount{$acctline->{itemnumber}}){
                    $verbose and warn "Recovered lost amount data from action_logs: $acctline->{accountno} ";
                    $acctline->{amount} = Koha::Money->new($fine_amount{$acctline->{itemnumber}});
                    if($acctline->{amountoutstanding} == $fine_amount{$acctline->{itemnumber}}){
                        $debits{$acctline->{accountno}} = $acctline;
                    } else {
                        $paidfines{$acctline->{accountno}} = $acctline;
                    }
                    delete $zeroed_fines{$acctline->{accountno}};
                    delete $fine_amount{$acctline->{itemnumber}};
                }
            }
            # now we still have left the ones without itemnumbers.
            # there's no way to reliably do it, so we'll just assign by amount unless amount<amountoutstanding, in which case we just give up.
            # yes, this is sloppy, but in most cases, we'll hope there's just one of these.
            # they are mostly items that have been removed.
         
            if(scalar values %fine_amount == scalar @sans_itemnumber){
                my @amount_list = sort values %fine_amount;
                for my $acct ( sort { $a->{amountoutstanding} <=> $b->{amountoutstanding} } @sans_itemnumber){
                    my $newval = shift @amount_list;
                    if($acct->{amountoutstanding} > $newval){
                        next;
                    } elsif($acct->{amountoutstanding} == $newval){
                        $acct->{amount} = Koha::Money->new($newval);
                        $debits{$acct->{accountno}} = $acct;
                    } else {
                        $acct->{amount} = Koha::Money->new($newval);
                        $paidfines{$acct->{accountno}} = $acct;
                    }
                }                
            }

        }

        # First take care of all the payments linked to items by finding associated payment lines.
        # Note that a given fine may have been written off while accruing, causing multiple entries.
        my $remaining_paidfines_amt = 0;  # track unhandled balance.
        my $resolved = 0;

        for my $f (sort {
            # handle fines that have a single ha string first,
            # then multiple ha strings, then those with itemnumbers.
            my $ha_pay_a = () = $paidfines{$a}->{description} =~ /paid at no\.\d+/g;
            my $ha_pay_b = () = $paidfines{$b}->{description} =~ /paid at no\.\d+/g;
            
            if($ha_pay_b && ($ha_pay_a > $ha_pay_b)){
                return 1;
            } elsif($ha_pay_a && ($ha_pay_a < $ha_pay_b)){
                return -1;
            } else {
                if($paidfines{$a}->{description} =~ /paid at no|writeoff at no/ && $paidfines{$b}->{description} !~ /paid at no|writeoff at no/ ){
                    return -1;
                } elsif($paidfines{$b}->{description} =~ /paid at no|writeoff at no/ && $paidfines{$a}->{description} !~ /paid at no|writeoff at no/ ){
                    return 1;
                } else {
                    
                    if($paidfines{$a}->{itemnumber} && !$paidfines{$b}->{itemnumber}){
                        return -1;
                    } elsif($paidfines{$a}->{itemnumber} && !$paidfines{$b}->{itemnumber}){
                        return 1;
                    } else {
                        return $a <=> $b;  # sort lastly by accountnumber.
                    }
                }
            }
        } keys(%paidfines)){  # $f is the accountno of this fine from accountlines.
            my $fee;
            my $trans;
            $verbose and warn "processing paid fines for borrower $borrowernumber,  accountno $f";
            my $accounttype = get_fine_accttype($paidfines{$f});
            unless($accounttype){
                $unknown{$f} = $paidfines{$f};
                next;
            }
            if($accounttype eq 'A' && $paidfines{$f}->{description} =~ /Sent to collections agency/){
                $accounttype = 'COLLECTIONS';
            }
            my $fine = {    borrowernumber  => $paidfines{$f}->{borrowernumber},
                            itemnumber      => $paidfines{$f}->{itemnumber},
                            amount          => $paidfines{$f}->{amount},
                            timestamp       => $paidfines{$f}->{date},
                            description     => $paidfines{$f}->{description},
                            notes           => sprintf("accountno:%d",$f),
                            accounttype     => $accounttype,
            };
            $fine->{branchcode} =  $paidfines{$f}->{branchcode} if($paidfines{$f}->{branchcode});

            if($paidfines{$f}->{accounttype} eq 'FFOR-SKIP-THIS-BLOCK'){
                # Formerly a 'F', forgiven. we don't expect to see a corresponding credit. so we'll forgive it using the timestamp on the accountline.
                # Occasionally, this will be a partial forgiveness.
   #  ALERT:
   #  MANY of these ARE actual payments.
   #  At the end, we should go back and test for this.
   #  See pioneer borrower 651067.
   #  Not likely a coincidence that we are off by the amount of this forgiveness line..
                $fine->{accounttype} = 'FINE';
                $fee = C4::Accounts::CreateFee($fine);
                my $to_wo = Koha::Money->new($paidfines{$f}->{amount});
                $trans = {  accounttype  => 'FORGIVE',
                            date         => $paidfines{$f}->{date},
                            amount      => -1*$to_wo + $paidfines{$f}->{amountoutstanding},
                            notes       => 'FFOR accountline',
                         };
                C4::Accounts::ApplyCredit( $fee , $trans );
                $verbose and warn sprintf "FFOR encountered with total forgiveness: %s", 1*$to_wo + $paidfines{$f}->{amountoutstanding};
                push @logoutput,  sprintf "$borrowernumber\t%s\t FFOR encountered.\n", 1*$to_wo + $paidfines{$f}->{amountoutstanding};
                delete $paidfines{$f};
                $resolved++;
                next;
            } elsif($paidfines{$f}->{accounttype} eq 'CR' && $paidfines{$f}->{description} !~ / paid at no\./){
                # If the accounttype is CR||LR and the amount is positive, this was a lost item that was later found.
                # It may or may not have an associated payment/writeoff.
                # Note there are also 'CR' with amount < 0, which is an RCR that has been refunded.  Those are handled elsewhere.
                # If we find an associated payment, we'll apply it, but sometimes there is no such line, so we'll SYSTEM it.
                
                # Or, it can be a claims returned.
                # We might see:
                # checkin as lost date  ## This is found on fee types F and FU as well as LR.  We ignore it.
                #    ^^^ checkin here means the item was removed from patron's account.  It should've said something like 'marked lost'
                # NO LONGER LOST date
                # Claims Returned:
                # We get one LR, amount < 0, and one FOR, amount > 0.
                # usually these should have strings like 'claims returned at no.\d'
                # The FOR line will say 'Claims returned at no.\d'
                # If the patron paid the fine, then the original fine will become a CR with amount >0 
                # and there will be a matching CR with amount < 0, and description 'Refund owed at no.\d' (where \d is the matching CR fine), and then possibly an 'issued at no.\d'
                # where \d is a 'REF' accounttype, with amount < 0, indicating the refund.  The amount may not match, though, since some of the REF may have been allocated to outstanding fines.
                # [see pioneer borrower 819871]
                # This is technically wrong, since negative amounts should represent CREDITS, and this is a DEBIT.  But that's how it's done.
                # There should be NO 'REF' accounttypes with amountoutstanding != 0, though, so it doesn't affect balance calculations.
                # The CR with amount < 0 is supposed to be refunded to patron. 
                # These come from RCR accountlines:
                # An RCR is a credit marked for refund.  When the refund is processed, it becomes a 'CR'.
                # So RCR lines will look like unallocated payments.
                # The credits are handled separately.
                # The credits/refunds will be handled as is -- i.e. the 'CR' (credit) and 'REF' lines will generate 'CREDIT' and 'REFUND' transactions.
                # This is different from how lost refunds are handled in the new code, but it's too much work to make them identical.
                
                # The CR lines might have a FOR line like the LR's do.
                
                # CR lines might also be paid L's with a corresponding unrefunded RCR.
                # These have / paid at no\.\d / in description, and are handled in the next block with paidfines.
                # (and the corresponding RCR will be handled in %credits).
                
                    $fine->{accounttype} = 'LOSTITEM';
                    $fee = C4::Accounts::CreateFee($fine);
                    if($paidfines{$f}->{description} =~ /claims returned at no\.(\d+)/){
                        $trans = {  accounttype  => 'CLAIMS_RETURNED',
                                date         => $payments{$1}->{timestamp},
                                description  => $payments{$1}->{'description'},
                             };

                        if($payments{$1}->{amount} != -1*$paidfines{$f}->{amount}){
                            $verbose and warn "Mismatched FOR line for CR accountline.  Borrower $borrowernumber, account $f , associated line $1";  
                            push @logoutput,  "Mismatched FOR line for CR accountline.  Borrower $borrowernumber, account $f , associated line $1\n";           
                            $has_discrepancy=1;                 
                        }
                        delete $payments{$1};

                    } else {
                        $trans = {  accounttype  => 'LOSTRETURNED',
                                date         => $paidfines{$f}->{timestamp},
                                notes       => 'accountline CR',
                             };
                    }
                    C4::Accounts::ApplyCredit( $fee , $trans );
                    delete $paidfines{$f};
                    $resolved++;
                    next;
            } elsif($paidfines{$f}->{accounttype} eq 'LR'){
                    # either claims returned and forgiven, or lostreturned with no associated credit line (likely from data migration).
                    # These should always have itemnumbers if there's a credit line.
                    # Some of these might be written off, but we will ignore those writeoffs.
                    # Note there are cases where Claims Returned will be 'recharged'; that should generate a new lost item fee, which should be handled on another iteration.
                    # Note also, early ClaimsReturned functionality had these as a 'CR' instead of 'LR'. 
                    $fine->{accounttype} = 'LOSTITEM';
                    $fee = C4::Accounts::CreateFee($fine);
                    if($paidfines{$f}->{description} =~ /claims returned at no\.(\d+)/ && $payments{$1}){
                        $trans = {  accounttype  => 'CLAIMS_RETURNED',
                                date         => $payments{$1}->{timestamp},
                                description  => $payments{$1}->{'description'},
                             };
                        if($payments{$1}->{amount} != -1*$paidfines{$f}->{amount}){
                            $verbose and warn "Mismatched FOR line for LR accountline.  Borrower $borrowernumber, account $f , associated line $1";
                            push @logoutput,  "Mismatched FOR line for CR accountline.  Borrower $borrowernumber, account $f , associated line $1\n";
                            $has_discrepancy=1;                            
                        }

                        delete $payments{$1};
                    } else {
                        $trans = {  accounttype  => 'LOSTRETURNED',
                                date         => $paidfines{$f}->{timestamp},
                                notes       => 'accountline LR',
                             };
                    }
                    C4::Accounts::ApplyCredit( $fee , $trans );
                    delete $paidfines{$f};
                    $resolved++;
                    next;

            } elsif($paidfines{$f}->{accounttype} eq 'FU'
                        || $paidfines{$f}->{accounttype} eq 'FFOR'
                        || $ACCT_TYPES{$accounttype}->{class} eq 'fee'
                        || $ACCT_TYPES{$accounttype}->{class} eq 'invoice'
                        || ($paidfines{$f}->{accounttype} eq 'CR' && $paidfines{$f}->{description} =~ / paid at no\./)
                        || $paidfines{$f}->{accounttype} eq 'C'     # fine added via manualcredit.
                ){
                # Any other fine type with zero outstanding should have a corresponding credit type.
                # If the accruing overdue fine was written off / forgiven while still accruing, we only keep the last writeoff (full amount).
                # No way to know if it was writeoff or payment from the fine itself.
                # First determine if this fine is unique.  If there are multiple fines for the same itemnumber, try to associate the correct payment with each fine.
                # Note it's possible that partial payments were made while the fine was accruing.
                # Most common will be just a full payment or writeoff.  If we find this, resolve this fine and move on.
                # If not, we'll come back in a second pass with the resolved ones out of the way.
                
                # First get any linked payments.  -- Note it's possible that the date of the payment will be before the 
                # date of the fine since the date may have been updated when the fine changed from 'FU' to 'F'.
                $accounttype = 'FINE' if($paidfines{$f}->{accounttype} eq 'FU' || $paidfines{$f}->{accounttype} eq 'FFOR');
                if($paidfines{$f}->{accounttype} eq 'CR'){
                    $accounttype = 'LOSTITEM'; 
                };
                $fine->{accounttype} = $accounttype;
                $fee = C4::Accounts::CreateFee($fine) if($paidfines{$f}->{amount} > 0);
                $paidfines{$f}->{fee_id} = $fee->{id};  # for the second pass.
                

                my $credit_total = Koha::Money->new(); # note payment amounts are negative, but we keep this value positive.
                my $amount_paid = $paidfines{$f}->{amount} - $paidfines{$f}->{amountoutstanding};
                $verbose and warn "processing paidfine $f, paid $amount_paid /  $paidfines{$f}->{amount}  ";
                my @ha_pay;
                my @ha_wo;
                my @partial_pay;
             
                while($paidfines{$f}->{description} =~ / (Fine Payment|Waiver of Fine|Adjustment debit|Balancing Entry|Adjustment credit|Misc\. charges|Found|Claimed Return) (\d{4}-\d{2}-\d{2}) (-?\d+\.\d{2})/g){
                    push @partial_pay, {desc=>$1,date=>$2, amt=>$3};
                }
                # some migrated payments have no associated accountline, but are tucked in description.
                # There are several such strings, probabaly these are Pioneer-specific, so this may have to be
                # adjusted for other sites.
                # rather than adding credits/debits for each, we just sum them and use the orig desc.
                # this should give us the right amountoutstanding in most cases.
                # Note there are cases where the original fine winds up as a credit.  These may fail if they were somehow 'paid' against other fines, but I don't see examples of that (yet)
                if(scalar @partial_pay > 0){
                    my $total = Koha::Money->new();
                    $total += $_->{amt} for(@partial_pay);

                    $total = -1 * $amount_paid if -1*$total > $amount_paid;  # There are cases where there are too many of these.

					# There are cases where this total is in fact positive. 
					# we could adjust the fine amount in that case, but instead we'll just drop it and hope it works out.
					if($total < 0){
                        $verbose and warn "Paying $total / $amount_paid per partial pay description substr.";
                        my $amount_to_pay = Koha::Money->new($total);
                        $credit_total += -1*$amount_to_pay;
                        $trans = {  accounttype => 'CREDIT',
                                    date        => $paidfines{$f}->{date},
                                    description => $paidfines{$f}->{description},
                                    amount      => $amount_to_pay,
                                    notes       => sprintf("accountno:%d",$f),
                                    borrowernumber => $borrowernumber,
                                 };
    
                        my ($new_pmt , $err) = C4::Accounts::_insert_new_payment($trans);
                        my $amt_to_allocate = max($amount_to_pay, -1*$paidfines{$f}->{amount});
                        my ($unallocated,$unpaid) = C4::Accounts::allocate_payment( payment=>$new_pmt, fee=>$fee, amount=>$amt_to_allocate );
                        $fee->{amountoutstanding} = $unpaid;
                        # We kind of bypass this check below and just allow a credit.  It'll catch it at the end if things don't add up.
                        if($credit_total == $amount_paid){
                            $resolved++;
                            delete $paidfines{$f};
                            next;
                        } elsif($credit_total > $amount_paid){
                            $verbose and warn "Overpayment @  borrower $borrowernumber, fee_id $fee->{id}";
                            push @logoutput,  "Overpayment @  borrower $borrowernumber, fee_id $fee->{id}\n";
                            $has_discrepancy=1;
                        }
					} elsif($total > 0){
						push @logoutput, "$borrowernumber\t$total\tNet debit against migrated data.\n";
					}
					
                }

                while($paidfines{$f}->{description} =~ / paid at no.(\d+)/g){
                    push @ha_pay, $1;
                }
                if(scalar @ha_pay > 0){
                    $verbose and warn sprintf("Matched %d payments on fine by ha string.", scalar @ha_pay);
                    
                    for my $payline (@ha_pay){
                        # Some Fines become credits when claimsreturned, and end up allocated with payments.
                        my @cr_credits = grep {$payments{$_}->{description} =~ / paid at no\.$payline /} keys %payments;
                        push @ha_pay, @cr_credits;
                        
                        if($reversed_payments{$payline}){
                            while($reversed_payments{$payline}->{description} =~ /paid at no.(\d+)/g){
                                $verbose and warn "Found payment reversal at $1 ";
                                push @ha_pay, $1;
                            }
                            # Not all of these will actually be payments against this fine, but if we do them
                            # in order, then hopefully it will all work out.
                            # This may fail when the fines aren't handled in the right order, but that's a very 
                            # hard problem.
                            # FIXME: Also, we shouldn't really push -- these should be inserted at the index of $payline.
                            # will fix if that comes up...
                            next;

                        }
                        # We could try harder here, but we'll let it die below...
                        # or just leave it unpaid and let the credit be distributed at the end.
                        # See pioneer borrower 661307 .
                        # If we don't use all the payment amount, we leave the payment in place, and add the new payment_id to its hash.

                        my $amount_to_pay = Koha::Money->new();
                        my $payment;
                        
                        if($payments{$payline}){
                            $payment = $payments{$payline};
                            $amount_to_pay = min($amount_paid-$credit_total, -1*($payment->{amount} + $payment->{allocated}));
                            
                        } else {
                            # might be in credits if the payment was partially allocated.
                            $verbose and warn  "Missing payment line for borrower $borrowernumber, fee id: $fee->{id} on accountline $payline";
                            # There are cases where:
                            #  * multiple partial pays on multiple fines cannot be reliably matched.
                            #    In these cases, there will be improper matching, and we will just hope it all adds up in the end.
                            #  * RCR's can be converted to payments, altering the payment amount (though these will hopefully be caught elsewhere) see pioneer 646213
                            #  * there are cases where the payment amounts don't add up.

                        }
                        if($payment){                            
                            $verbose and warn sprintf "Paying %s from acct %d (%s)",$amount_to_pay,$payline, $payment->{amount} + $payment->{allocated};
                            $credit_total += $amount_to_pay;
                            my ($new_pmt, $err);
                            if(exists $payment->{payment_id}){
                                $verbose and warn "Allocating payment $payment->{payment_id}.";
                                my ($unallocated,$unpaid) = C4::Accounts::allocate_payment(payment=>$payment->{payment_id},fee=>$fee, amount=>$amount_to_pay);
                                $fee->{amountoutstanding} = $unpaid;
                            } else {
                                $verbose and warn "Creating new payment for accountno $payline";
                                $trans = {  accounttype => 'PAYMENT',
                                            date        => $payment->{date},
                                            description => $payment->{description},
                                            notes       => sprintf("accountno:%d",$payline),
                                            amount      => $payment->{amount},
                                            borrowernumber => $borrowernumber,
                                         };
                                ($new_pmt , $err) = C4::Accounts::_insert_new_payment($trans);
                                my ($unallocated,$unpaid) = C4::Accounts::allocate_payment( payment=>$new_pmt, fee=>$fee, amount=>$amount_to_pay );
                                $fee->{amountoutstanding} = $unpaid;
                                $payment->{payment_id} = $new_pmt->{id};
                            }

                            if($payment->{allocated} + $payment->{amount} == -1.0 * $amount_to_pay){
                                delete $payments{$payline};                                
                            } else {
                                $payment->{allocated} += $amount_to_pay;                                
                            }
                            last if($credit_total == $amount_paid);
                        }
                    }
                    
                    if($credit_total == $amount_paid){
                        $resolved++;
                        delete $paidfines{$f};
                        next;
                    } elsif($credit_total > $amount_paid){
                        push @logoutput,  "Overpayment @  borrower $borrowernumber, fee_id $fee->{id}\n";
                        $has_discrepancy=1;
                    } else {
                        # Note, this might happen in case of partial payments with writeoffs.
                        # There may, in fact, be an amountoutstanding on this fine even though this accountline looks paid
                        # since a reversed payment might have been partially paid.
                        # ... continue to check writeoffs.
                        
                    }
                }
                if($accounttype eq 'LOSTITEM'){
                    # there are cases where the accounttype didn't go from L to LR or CR when claims returned.
                    if($paidfines{$f}->{description} =~ / claims returned at no\.(\d+) /){
                        $trans = {  accounttype  => 'LOSTRETURNED',
                                date         => $payments{$1}->{timestamp},
                                description  => $payments{$1}->{'description'},
                             };
                        if($payments{$1}->{amount} != -1*$paidfines{$f}->{amount}){
                            push @logoutput,  "Mismatched FOR line for LR accountline.  Borrower $borrowernumber, account $f , associated line $1\n";
                            $verbose and warn "Mismatched FOR line for LR accountline.  Borrower $borrowernumber, account $f , associated line $1";
                            $has_discrepancy=1;
                        }
       ### FIXME: This is probably wrong when there is a credit against the lost item fee.
                        delete $payments{$1};
                        C4::Accounts::ApplyCredit( $fee , $trans );
                        delete $paidfines{$f};
                        $resolved++;
                        next;                           
                    }
                }
                while($paidfines{$f}->{description} =~ /writeoff at no.(\d+)/g){
                    push @ha_wo, $1;
                }
                if(scalar @ha_wo > 0){
                   $verbose and warn sprintf("Matched %d writeoffs on fine by ha string.", scalar @ha_wo);
                    for my $payline (@ha_wo){
                        my $payment;
                        if($linked_writeoffs{$payline}){
                            $payment = $linked_writeoffs{$payline};
                            delete $linked_writeoffs{$payline};
                        } elsif($unlinked_writeoffs{$payline}){
                            $payment = $unlinked_writeoffs{$payline};
                            delete $unlinked_writeoffs{$payline};
                        } else {
                            # missing payment line.
                            $verbose and warn "Missing writeoff line for borrower $borrowernumber, fee id: $fee->{id} on accountline $payline";
                            # try credits ??
                        }
                        if($payment){
                            if ($payment->{amount} > 0){
                                $verbose and warn "Positive WRITEOFF amount at $payline";
                                push @logoutput,  "Positive WRITEOFF amount $payment->{amount} at $payline\n";
                                $has_discrepancy=1;
                                
                            }
                            my $to_writeoff = max($payment->{amount}, $credit_total - $amount_paid ); # Some lines have excess writeoff amounts. There are no partial writeoffs.
                            $credit_total -= $to_writeoff;
                            $trans = {  accounttype => 'WRITEOFF',
                                        date   => $payment->{date},
                                        description => $payment->{description},
                                        notes       => sprintf("accountno:%d",$payline),
                                        amount      => $to_writeoff,
                                     };
                            C4::Accounts::ApplyCredit( $fee , $trans );                             
                        }
                    }
                    
                    if($credit_total == $amount_paid){
                        $resolved++;
                        delete $paidfines{$f};
                        next;
                    } elsif($credit_total > $amount_paid){
                        push @logoutput,   "Overpayment @  borrower $borrowernumber, fee_id $fee->{id}\n";
                        $verbose and warn "Overpayment @  borrower $borrowernumber, fee_id $fee->{id}";
                        $has_discrepancy=1;
                    } else {
                        # ... continue to check for ha strings in payments...
                    }
                }
                
                # If still here, there's still a balance.
                # It may be an old, pre-ha fine, though the payment line may have ha text.
                # Ha text can be:  "Payment for no.\d", "Payment for No.\d", or "Payment for .* (No.\d), Thanks"
                # There is a rare case wherein a reversed payment is paid and also reversed, then that one is paid.  That will probably fail.
    
                # These @ha_pays are mostly to cover cases prior to when ha added the 'paid at no.' string to the fee line and for reversed payments, where the 'real' payment ends up paid against the reversed payment line.
                my @ha_pay_linked = grep { $payments{$_}->{accounttype} eq 'Pay' && $payments{$_}->{itemnumber}
                                            && ($payments{$_}->{description} =~ /Payment for [Nn]o\.$f / || $payments{$_}->{description} =~ /Payment for .* \(No\.$f\), Thanks/ )
                                            } keys %payments;
                my @ha_pay_unlinked = grep { $payments{$_}->{accounttype} eq 'Pay' && ! $payments{$_}->{itemnumber}
                                            && ($payments{$_}->{description} =~ /Payment for [Nn]o\.$f / || $payments{$_}->{description} =~ /Payment for .* \(No\.$f\), Thanks/ )
                                            } keys %payments;
                
                
                @ha_pay = (@ha_pay_linked, @ha_pay_unlinked);

                if(scalar @ha_pay > 0){
                    $verbose and warn sprintf("Matched %d payments on fine by ha string in payment line.", scalar @ha_pay);
                    for my $payline (@ha_pay){
                        # There are at least a couple cases where there are duplicate payments.  Probably a short-lived bug.
                        # These payments otherwise should match the fine amount.
                        if($payments{$payline} && $credit_total < $payments{$payline}->{amount} * -1 ){
                            $credit_total -= $payments{$payline}->{amount};
                            $trans = {  accounttype => 'PAYMENT',
                                        date   => $payments{$payline}->{date},
                                        description => $payments{$payline}->{description},
                                        notes       => sprintf("accountno:%d",$payline),
                                        amount      => $payments{$payline}->{amount},
                                     };
                            C4::Accounts::ApplyCredit( $fee , $trans );                            
                            delete $payments{$payline};
                        } else {
                            # missing payment line.
                            $verbose and warn "Missing payment line for borrower $borrowernumber, fee id: $fee->{id} on accountline $payline";
                            push @logoutput,  "$borrowernumber\t$payments{$payline}->{amount}\tMissing payment line for borrower $borrowernumber, fee id: $fee->{id} on accountline $payline\n";
                            $has_discrepancy=1;
                            # try credits ??
                        }
                    }
                    if($credit_total == $amount_paid){
                        $resolved++;
                        delete $paidfines{$f};
                        next;
                    } elsif($credit_total > $amount_paid){
                        $verbose and warn "Overpayment on borrower $borrowernumber, fee_id $fee->{id}";
                        push @logoutput,  "$borrowernumber\t$amount_paid\tOverpayment on fee_id $fee->{id}\n";
                        $has_discrepancy=1;
                    } else {
                        $verbose and warn "Partial payments didn't add up.";
                        $verbose and warn "Credited so far: $credit_total  /  $amount_paid";
                        # Note, this might happen in case of reversed payments.
                    }
                }
                    
                # If we're still here, we're mostly looking for full payments or writeoffs (non-ha-matched),
                # Or possibly a partial payment or writeoff while the fine was still accruing.
                # In all these cases, the amount should match the remaining amount on the fine (after the ha stuff above has been handled).
                my $amount_left = $amount_paid - $credit_total;
                
                my @matched_wo = grep { $_->{description} =~ /Writeoff for No.$f / } values %linked_writeoffs;
                push @matched_wo, grep { $_->{description} =~ /Writeoff for No.$f / } values %unlinked_writeoffs;
                if(scalar @matched_wo > 1){
                    $verbose and warn "Matched multiple writeoffs.  Handle this. borno $borrowernumber account $f";
                    push @logoutput,  "$borrowernumber\t$amount_left\tMatched multiple writeoffs. borno $borrowernumber account $f\n";
                    $has_discrepancy=1;
                } elsif(scalar @matched_wo == 1){
                    my $wo_line = $matched_wo[0];
                    my $to_writeoff = max($wo_line->{amount}, -1*$amount_left ); # Some lines have excess writeoff amounts.
                    $trans = {  accounttype => 'WRITEOFF',
                                date        => $wo_line->{date},
                                amount      => $to_writeoff,   # NOTE, this might be positive in pre-ha data.
                                description => $wo_line->{description},
                                notes       => sprintf("accountno:%d",$wo_line->{accountno})
                             };
                    if(C4::Accounts::ApplyCredit( $fee , $trans )){
                        $verbose and warn "$borrowernumber Bad writeoff line at $wo_line";
                        push @logoutput,  "$borrowernumber\t$amount_left\tBad writeoff line at $wo_line";
                        $has_discrepancy=1;
                        
                    }
                    delete $paidfines{$f};
                    if(exists $wo_line->{itemnumber}){
                       delete $linked_writeoffs{$wo_line->{accountno}};  
                    } else {
                        delete $unlinked_writeoffs{$wo_line->{accountno}};   
                    }
                    $resolved++;
                    next;                    
        }
                
                #First, try to match linked payment by itemnumber.  if no, hope that timestamp is enough...
                                
                my @f_pay = grep { $payments{$_}->{itemnumber}
                                && ($paidfines{$f}->{itemnumber} && $payments{$_}->{itemnumber} eq $paidfines{$f}->{itemnumber})
                                && $payments{$_}->{accounttype} eq 'Pay' 
                                && $payments{$_}->{amount} == -1 * $amount_left
                                } keys %payments;
                if(@f_pay){
                    my $pay_line;
                    if(scalar(@f_pay) > 1){
                        # matched multiple full payments.  see if one matches timestamp.
                        my @lines = grep { $payments{$_}->{timestamp} eq $paidfines{$f}->{timestamp} } @f_pay;
                        $pay_line = $lines[0] if(scalar(@lines) == 1);
                    } else {
                        $pay_line = $f_pay[0]; # unique payment accountline.
                    }
                    if($pay_line){
                        # Found unique payment.
                        $trans = {  accounttype => 'PAYMENT',
                                    date   => $payments{$pay_line}->{date},
                                    description => $payments{$pay_line}->{description},
                                    notes       => sprintf("accountno:%d",$pay_line),
                                    amount      => -1 * $amount_left,
                                 };
                        C4::Accounts::ApplyCredit( $fee , $trans );
                        delete $paidfines{$f};
                        delete $payments{$pay_line};
                        $resolved++;
                        next;
                    }
                } else {
                    # try to match a writeoff by itemnumber.
                    my $wo_line;
                    no warnings qw(uninitialized);
                    my @f_wo = grep { $linked_writeoffs{$_}->{itemnumber} eq $paidfines{$f}->{itemnumber} 
                                && $linked_writeoffs{$_}->{amount} == -1 * $amount_left
                                } keys %linked_writeoffs;   # writeoffs don't seem to update fine's timestamp, so don't match on timestamp.
             
                    if(@f_wo){
                        $verbose and warn "Matched writeoff(s): ".join(',',@f_wo);

                        $wo_line = $f_wo[0];
                        # This isn't right, but close enough.  Should probably test for sane date relation, but instead, if there are multiple writeoffs for multiple fines on the same item, just link them randomly.
                        # Alternately they are multiple fines of the same amount.  matching timestamp apparently didn't work too well, so we allow this slop.
                       # unless($paidfines{$f}->{accounttype} eq 'FU' && $paidfines{$f}->{description} !~ /returned \d\d\//){

                           my $to_writeoff = max($linked_writeoffs{$wo_line}->{amount}, -1*$amount_left ); # Some lines have excess writeoff amounts.
                            $trans = {  accounttype => 'WRITEOFF',
                                        date        => $linked_writeoffs{$wo_line}->{date},
                                        amount      => $to_writeoff,   # NOTE, this might be positive in pre-ha data.
                                        description => $linked_writeoffs{$wo_line}->{description},
                                        notes           => sprintf("accountno:%d",$wo_line)
                                     };
                            if(C4::Accounts::ApplyCredit( $fee , $trans )){
                                $verbose and warn "$borrowernumber Bad writeoff line at $wo_line";
                                push @logoutput,  "$borrowernumber Bad writeoff line at $wo_line";
                                $has_discrepancy=1;
                                
                            }
                            delete $paidfines{$f};
                            delete $linked_writeoffs{$wo_line};
                            $resolved++;
                            next;
                       # }
                    }
                }
                # No linked payments/writeoffs were found; try unlinked payments.
                @f_pay = grep { $payments{$_}->{accounttype} eq 'Pay' && ! $payments{$_}->{itemnumber}
                                    && $payments{$_}->{amount} == -1 * $amount_left
                                    } keys %payments;

        
                if(@f_pay){
                    $verbose and warn "FOUND Unlinked payment for accountno $f; amount left: $amount_left .";
                    my $pay_line;
                    if(scalar(@f_pay) > 1){
                        # matched multiple full payments.  see if one matches timestamp.  ## Note this no longer works after partial pays were added.
                        my @lines = grep { $payments{$_}->{timestamp} eq $paidfines{$f}->{timestamp} } @f_pay;
                        $verbose and warn "Matched linked fine to multiple unlinked payments by timestamp." if(scalar(@lines) > 1);
                       
                        $pay_line = $lines[0]; # if(scalar(@lines) == 1);  # assume it's ok; probably just multiple payments on multiple fines of the same amount.
                    } else {
                        $pay_line = $f_pay[0]; # unique payment accountline.
                    }
                    if(defined $pay_line){
                        # Found unique payment.
                        $trans = {  borrowernumber => $borrowernumber,
                                    accounttype => 'PAYMENT',
                                    date        => $payments{$pay_line}->{date},
                                    description => $payments{$pay_line}->{description},
                                    notes       => sprintf("accountno:%d",$pay_line),
                                    amount      => -1 * $amount_left,
                                 };
                        C4::Accounts::ApplyCredit( $fee , $trans );
                        delete $paidfines{$f};
                        delete $payments{$pay_line};
                        $resolved++;
                        next;
                    }
                } else {
                    # lastly, look for unlinked writeoffs .  # Note we havne't looked for 'Writeoff for No.\d+' yet; we should do that first...
                    my $wo_line;
                    my @f_wo = grep { $unlinked_writeoffs{$_}->{amount} == -1 * $amount_left
                                && $unlinked_writeoffs{$_}->{timestamp} eq $paidfines{$f}->{timestamp}
                                } keys %unlinked_writeoffs;
                    if(@f_wo){
                        $verbose and warn "Matched writeoff(s): ".join(',',@f_wo);
                        if(scalar(@f_wo) > 1){
                            # matched multiple unlinked writeoffs.  see if one matches timestamp.
                            #my @lines = grep { $linked_writeoffs{$_}->{timestamp} eq $unlinked_writeoffs{$f}->{timestamp} } @f_wo;
                            # 2009-10-15: rch: if we matched more than one writeoff, go ahead and link them.  In most cases this will just be multiple fines with same amounts.
                            # $wo_line = $lines[0] if(scalar(@lines) == 1);
                            $wo_line = $f_wo[0];
                        } else {
                            $wo_line = $f_wo[0]; # unique writeoff accountline.
                        }
                        $trans = {  accounttype => 'WRITEOFF',
                                    date        => $unlinked_writeoffs{$wo_line}->{date},
                                    amount      =>  -1 * $amount_left,
                                    description => $unlinked_writeoffs{$wo_line}->{description},
                                 };
                        C4::Accounts::ApplyCredit( $fee , $trans );
                        delete $paidfines{$f};
                        delete $unlinked_writeoffs{$wo_line};
                        $resolved++;
                        next;
                    }
                }

                # If we're still here, we couldn't find suitable credits to link to this fine (there is at least some portion unhandled).
                # Stash the remaining amount in the hash,
                # we leave it in $paidfines and report later .
                if($amount_left){
                    $paidfines{$f}->{'unhandled'} = $amount_left;
                    $remaining_paidfines_amt += $amount_left;
                }

            } else {
                $verbose and warn "UNKNOWN ACCOUNTTYPE !! : $accounttype";
                push @logoutput,  "$borrowernumber UNKNOWN ACCOUNTTYPE !! : $accounttype\n";
                $has_discrepancy=1;
            }
            # If we failed to match the paid fine to a credit, it stays in paidfines
        }
        $verbose and warn "Finished first pass at paid fines. Resolved $resolved fines,  Unresolved paid fines: " .scalar(keys %paidfines);
        # Done with paid fines. (first pass).

        # Next, handle credits for claims returned / lostreturned.
        # These are RCR's that have been refunded.  each CR should have a corresponding REF.
        for my $f (keys(%refunded_rcrs)){
            $verbose and warn "processing refunded credits for borrower $borrowernumber accountno $f";
            my $credit = {  borrowernumber  =>  $refunded_rcrs{$f}->{borrowernumber},
                            amount          => $refunded_rcrs{$f}->{amount},
                            date            => $refunded_rcrs{$f}->{date},
                            description     => $refunded_rcrs{$f}->{description},
                            notes           => sprintf("accountno:%d",$f),
                            accounttype     => 'CREDIT',
            };
            if($credit->{description} =~ /, issued at no\.(\d+)/){
                my $refund_accountno = $1;
                # The refund may have been partially paid to patron and partially applied to outstanding fees, usu. with no ha string.
                # This should leave us with some of the credit unallocated to the REFUND. 
                # At this point, we should probably put the refund into payments in case we have remaining paidfines to balance
                # (we might need to drop the extra credit), but for now we'll just leave some unallocated.
                # 
                # It's also possible that one REFUND is issued for multiple CR's.
                # So we allow that, and leave the refund in place.
                #  -- it's also possible that the refunded amounts don't add up.  see pioneer bor 722728,
                #     where one REFUND is issued for two CR's but the refund amount is in the amount of only one of the CR's.

                my ($pmt_inserted , $pmt_error) = C4::Accounts::_insert_new_payment( $credit );
                my ($unallocated,$unpaid);
                if( exists $refunds{$refund_accountno} && defined $refunds{$refund_accountno}->{fee_id}){
                    ($unallocated,$unpaid) = C4::Accounts::allocate_payment( payment=>$pmt_inserted, fee=>$refunds{$refund_accountno}->{fee_id} );
                } elsif( exists $refunds{$refund_accountno} ){
                    my $fine = {    borrowernumber  => $refunds{$refund_accountno}->{borrowernumber},
                                    itemnumber      => $refunds{$refund_accountno}->{itemnumber},
                                    amount          => -1 * $refunds{$refund_accountno}->{amount},
                                    timestamp       => $refunds{$refund_accountno}->{date},
                                    description     => $refunds{$refund_accountno}->{description},
                                    notes           => sprintf("accountno:%d",$refund_accountno),
                                    accounttype     => 'REFUND',
                    };
                    my $fee = C4::Accounts::CreateFee($fine);
                    $refunds{$refund_accountno}->{fee_id} = $fee->{id};
                    ($unallocated,$unpaid) = C4::Accounts::allocate_payment( payment=>$pmt_inserted, fee=>$fee );
                } 
                delete $refunded_rcrs{$f};
                delete $refunds{$refund_accountno} unless $unpaid;

            } else {
                $verbose and warn "Couldn't match REFUND to CREDIT.";                
                push @logoutput,  "$borrowernumber Couldn't match REFUND to CREDIT. $f\n";    
                $has_discrepancy=1;            
            }

        }
        if(scalar keys %refunded_rcrs > 0 || scalar keys %refunds > 0){
            $verbose and warn p %refunds;
            $verbose and warn p %refunded_rcrs;
            $verbose and warn " Didn't handle all the refunds...";
            push @logoutput,  "$borrowernumber   Didn't handle all the refunds...\n";
            $has_discrepancy=1;
        }
        

        ###############################
        # NEXT, take care of outstanding credits.
        # However, we'll attempt to match an outstanding debit on amount first.  If we don't find a match, we'll just insert the credit, and leave it unallocated.
        $resolved = 0;
        my $linked_debits = 0;
        foreach my $f ( keys(%credits)){  # $f is the accountno of this accountline
            my $fee;
            my $trans;
            $verbose and warn "processing outstanding credits for borrower $borrowernumber,  accountno $f";
            my $accounttype = $x{$credits{$f}->{accounttype}};
#            if($credits{$f}->{accounttype} eq 'F'){
#                # Migrated data.
#                # Some of these are Lost/Returned. Some have payments/other transactions.  Too hard to handle
#                # so we just act like it's a straight credit.
#                $credits{$f}->{amount} = $credits{$f}->{amountoutstanding};
#                $accounttype = 'CREDIT';                
#            }
            if($ACCT_TYPES{$accounttype}->{class} eq 'invoice' || $ACCT_TYPES{$accounttype}->{class} eq 'fee' || $credits{$f}->{accounttype} eq 'FOR'){
                # a bug apparently allowed people to create credits with invoices.
                # these can also be class 'fee'; manualinvoice allows any 'L', 'F', etc.  
                # We'll put it in so that the numbers add up, as a CREDIT.
                # We also include FOR, which can be a Manual-Credit-created Forgiveness credit.
                # It'll become a full credit, though, since we likely don't know what it was intended to be associated with.
                 $accounttype = 'CREDIT';
            }
            if($ACCT_TYPES{$accounttype}->{class} ne 'payment'){
                $verbose and warn "$borrowernumber Unknown CREDIT accounttype: $accounttype || $credits{$f}->{accounttype}\n";
                push @logoutput,  "$borrowernumber Unknown CREDIT accounttype: $accounttype || $credits{$f}->{accounttype}\n" unless $ACCT_TYPES{$accounttype}->{class} eq 'payment';
                $has_discrepancy=1;                
            }
            
            if(!$accounttype || ($credits{$f}->{amount} && ( $credits{$f}->{amount} != $credits{$f}->{amountoutstanding}))){
                # some credits may have an amount of zero, and only reflect the credit in amountoutstanding.
                # if amount is defined != amountoutstanding, bail.
                $unknown{$f} = $credits{$f};
                next;
            }
            my $payment = { borrowernumber  => $credits{$f}->{borrowernumber},
                            itemnumber      => $credits{$f}->{itemnumber},
                            date            => $credits{$f}->{date},
                            description     => $credits{$f}->{description},
                            amount          => $credits{$f}->{amountoutstanding},
                            accounttype     => $accounttype,
                            notes       => sprintf("accountno:%d",$f),
            };
            my @fee_match = grep { $debits{$_}->{amountoutstanding} == -1 * $credits{$f}->{amountoutstanding} } keys %debits;
            my $matched_fee;
            if(@fee_match){
                if(scalar(@fee_match) > 1){
                    # matched multiple fees.  ## TODO : try some pattern matching on descriptions.
                    $verbose and warn "Matched multiple credits to fee.";
                    my @lines = grep { defined($debits{$_}->{itemnumber}) && defined($credits{$f}->{itemnumber}) && $debits{$_}->{itemnumber} == $credits{$f}->{itemnumber} } @fee_match;
                    if(scalar(@lines) == 1){
                        $verbose and warn "Matched credit to fee by itemnumber.";
                        $matched_fee = $lines[0];
                    } else {
                        my @datematch = grep { $debits{$_}->{date} eq $credits{$f}->{date} } @fee_match;
                        if(scalar(@datematch)){
                            $verbose and warn "Matched credit to fee by date";
                            $matched_fee = $datematch[0];
                        } else {
                            $verbose and warn "no unique match for credit.";
                        }
                    }
                } else {
                    $matched_fee = $fee_match[0]; # unique fine accountline.
					$verbose and warn "Matched credit $payment->{notes} to fee $matched_fee";
                }
                if($matched_fee){
					no warnings qw(uninitialized);
                    if($debits{$matched_fee}->{amountoutstanding} != $debits{$matched_fee}->{amount}){
                        $verbose and warn "ERROR IN FEE:  UNRESOLVED PARTIAL PAYMENT.";
                    }
                    # Found fee to match credit against.
                   my $fine = {    borrowernumber   => $debits{$matched_fee}->{borrowernumber},
                                    amount          => $debits{$matched_fee}->{amount},
                                    timestamp       => $debits{$matched_fee}->{date},
                                    description     => $debits{$matched_fee}->{description},
                                    itemnumber          => $debits{$matched_fee}->{itemnumber},
                    };

					my $accounttype = get_fine_accttype($debits{$matched_fee});
                    $fine->{accounttype} = ($accounttype && $ACCT_TYPES{$accounttype}->{class} eq 'fee') ? $accounttype : 'SUNDRY';  # if we don't know the fine type, mark it sundry.
                    $fee = C4::Accounts::CreateFee($fine);
                    $trans = {  accounttype => 'PAYMENT',
                                date        => $debits{$matched_fee}->{date},
                                description => $debits{$matched_fee}->{description},
                             };
                    C4::Accounts::ApplyCredit( $fee , $trans );
                    delete $credits{$f};
                    delete $debits{$matched_fee};
                    $resolved++;
                    $linked_debits++;
                }
            }
            unless($matched_fee) {
                # No matching fee found, just insert the credit.
                # We'll use manualcredit for this, and try to retain any other information by stuffing it into the description.
                $payment->{description} = ($payment->{description}) ? '[ '.$payment->{accounttype}.' ] '.$payment->{description}
                                            : '[ '.$payment->{accounttype}.' ] ';
                $payment->{accounttype} = 'CREDIT' unless $payment->{accounttype};
                my $err = C4::Accounts::_insert_new_payment($payment);
                $verbose and warn $err if $err;
                delete $credits{$f};
                $resolved++;
            }
        }
        $verbose and warn "ADDED $resolved unlinked credits.  Unhandled unlinked credits: " .scalar(keys %credits);
        $verbose and warn "LINKED $linked_debits debits to those credits.  Remaining debits: " .scalar(keys %debits);

        ###############################
        # NEXT, transfer any outstanding debits.  These are unpaid.
        $resolved = 0;
        my $unlinked_debits = Koha::Money->new();
        foreach my $f ( keys(%debits)){  # $f is the accountno of this accountline
            $verbose and warn "processing remaining debit $f";
            if($debits{$f}->{amount} < $debits{$f}->{amountoutstanding}){
                # from a bug and/or data migration.
                $debits{$f}->{amount} = $debits{$f}->{amountoutstanding};
            }
            if($debits{$f}->{amountoutstanding} < $debits{$f}->{amount}){
                # If it's greater
                $verbose and warn "ERROR IN FEE:  UNRESOLVED PARTIAL PAYMENT.";
                push @logoutput,  "$borrowernumber\t$debits{$f}->{amountoutstanding}\tUnresolved partial payment on accountline $f / $debits{$f}->{description} \n";
                $has_discrepancy=1;
            }
            my $fine = {    borrowernumber  => $debits{$f}->{borrowernumber},
                            amount          => $debits{$f}->{amountoutstanding},
                            timestamp       => $debits{$f}->{date},
                            description     => $debits{$f}->{description},
                            itemnumber      => $debits{$f}->{itemnumber},
                            notes       => sprintf("accountno:%d",$f),
            };
            $unlinked_debits += $debits{$f}->{amountoutstanding};
            my $accounttype = get_fine_accttype($debits{$f});
            
            if($accounttype && ($ACCT_TYPES{$accounttype}->{class} eq 'fee' || $ACCT_TYPES{$accounttype}->{class} eq 'invoice' )){
                if($debits{$f}->{description} =~ /Sent to collections agency/){
                    $fine->{accounttype} = 'COLLECTIONS';
                } else {
                    $fine->{accounttype} = $accounttype;                
                }
            } else {
                $fine->{accounttype} = 'SUNDRY';  # if we don't know the fine type, mark it sundry.
            }

            my $fee = C4::Accounts::CreateFee($fine);
            if($fee){
                delete $debits{$f};
                $resolved++;
            }
        }
        $verbose and warn "ADDED $resolved unlinked debits.  Unhandled unlinked debits: " .scalar(keys %debits);
        
        # Now, let's see if there are any paidfines left over, and if there are matching payment/writeoffs left over.
        # This block below is fragile; There are cases from data migration (apparently) that
        # the payment amounts do not equal the sum of fine amounts on a zero-balance account.
        # This is likely due to a hard cutoff date on migrated fines data.

    
        my $totalowed = C4::Accounts::gettotalowed($borrowernumber);
        my $applied_unallocated_payments_amt = Koha::Money->new();
        my $remaining_payments_amt = Koha::Money->new();

        for(values %payments){
            if($_->{payment_id}){
                $applied_unallocated_payments_amt += $_->{amount} + $_->{allocated};
            }
            # There are cases (see pioneer borrower 798471, accountno 1)
            # where we get a negative Fine that looks like a fully allocated payment.
            # we'll go ahead and drop those here.
            if($_->{accounttype} eq 'F' && $_->{amountoutstanding} == 0){
                delete $payments{$_->{accountno}};
                next;
            }
            $remaining_payments_amt -= $_->{amount} + $_->{allocated}//0;
        }

        my $remaining_writeoffs_amt = Koha::Money->new();
        for (keys %linked_writeoffs){ $remaining_writeoffs_amt -= $linked_writeoffs{$_}->{amount}};
        for (keys %unlinked_writeoffs){ $remaining_writeoffs_amt -= $unlinked_writeoffs{$_}->{amount}}; 
        
        $verbose and warn "Begin second pass at paidfines.\nBalance: $balance / Totalowed: $totalowed\nRemaining paidfines amt: $remaining_paidfines_amt applied_unallocated: $applied_unallocated_payments_amt total remaining_payment: $remaining_payments_amt";
        
        if($totalowed == $balance && ! $remaining_payments_amt){
            # We're done.
        } elsif(($balance == $totalowed - $remaining_paidfines_amt) ||
                ($balance == $totalowed - $remaining_paidfines_amt - $applied_unallocated_payments_amt) ||
                ($balance == $totalowed - $remaining_paidfines_amt - $remaining_payments_amt) ||
                ($remaining_paidfines_amt == -1 * $applied_unallocated_payments_amt)
                ){
            # We didn't handle all the paidfines, but we're closer to done once we do.
            # FIXME: THIS Calculation is off; need to handle $remaining_payments_amt and $applied_unallocated_payments_amt
            
            # We finish by doing the following: 
            # enter as many payments as we can without exceeding the paid fines amount.
            # Once we hit the correct balance, (or have handled all the paidfines) we generate system transactions to hit amountoutstandings on
            # both payments and fines.
            # Start from most recent payment, and add them until we have enough to cover
            # paidfines.
            my $amt_left = $remaining_paidfines_amt;
PAY:        for my $payment (sort { if(exists $a->{payment_id} && ! exists $b->{payment_id}){
                                            return -1;
                                        } elsif(exists $b->{payment_id} && ! exists $a->{payment_id}){
                                            return 1;
                                        } else {
                                            return $b->{date} cmp $a->{date};
                                        }  # sort by whether payment has allocated amount first, then reverse-chrono by date.
                                    } values %payments){
                if(!exists $payment->{payment_id}){
                    $verbose and warn "Creating new payment for accountno $payment->{accountno} , amount: $payment->{amount}";
                    my $trans = {  accounttype => $x{$payment->{accounttype}},
                            date        => $payment->{date},
                            description => $payment->{description},
                            notes       => sprintf("accountno:%d",$payment->{accountno}),
                            amount      => $payment->{amount},
                            borrowernumber => $borrowernumber,
                         };
                    my ($new_pmt , $err) = C4::Accounts::_insert_new_payment($trans);
                    if(!$new_pmt){
                        # Have seen a few bad accounttypes -- so far they can be dropped...
                        $verbose and warn "Failed to create payment -- $err\n" . p $payment;
                        next PAY;
                    }
                    $payment->{payment_id} = $new_pmt->{id};
                }

                for my $fine (sort {$b->{date} cmp $a->{date}} values %paidfines){
                    if(!exists $fine->{fee_id}){
                        # we're not guaranteed to have a fee here.
                        warn "Failed to insert a fee.";
                        next;
                    }
                    my $to_pay = min( -1*$payment->{amount} -$payment->{allocated}, $fine->{unhandled});
                    $verbose and warn "Allocating $to_pay from $payment->{payment_id} toward $fine->{fee_id}";
                    my ($unallocated,$unpaid) = C4::Accounts::allocate_payment( payment=>$payment->{payment_id}, fee=>$fine->{fee_id}, amount=>$to_pay);
                    $amt_left = $amt_left - $to_pay -$unpaid;
                    $payment->{allocated} += $to_pay - $unpaid;
                    if($unpaid == 0){
                        delete $paidfines{$fine->{accountno}};
                    } else {
                        $fine->{unhandled} = $unpaid;                        
                    }
                    if($unallocated==0){
                        delete $payments{$payment->{accountno}};
                        next PAY;
                    }
                }
                # If we made it here, paidfines should be gone, and our payment has some left over.  We generate a SYSTEM fee to cover the unallocated amount.
                # In most of these cases, there was a fine that Koha lost.
                my $p = C4::Accounts::getpayment($payment->{payment_id}, unallocated=>1);
                if(exists $p->{unallocated} && $p->{unallocated}->{amount}){
                    push @logoutput,  "$borrowernumber\t$p->{unallocated}->{amount}\tADDING SYSTEM DEBIT to balance unhandled payment amount $p->{unallocated}->{amount} / $payment->{amount} from payment_id $p->{id} / accountline $payment->{accountno}.\n";
                    $verbose and warn "ADDING SYSTEM DEBIT of amount $p->{unallocated}->{amount} from accountline $payment->{accountno} to equalize balance.";
                    $has_discrepancy=1;
                    my $trans = {   borrowernumber => $borrowernumber,
                                    accounttype => 'SYSTEM_DEBIT',
                                    timestamp        => $p->{date},
                                    description => "System-mediated debit to balance account.",
                                    amount      => -1 * $p->{unallocated}->{amount},
                                    notes       => sprintf("accountno:%d",$payment->{accountno}),
                            };                   
                    C4::Accounts::CreateFee($trans);
                }
    #            last unless scalar keys %paidfines;
    # Don't stop when we handle all the paidfines; we still need to address any payments that didn't get handled.            
            }
            # Pay out remaining paidfines.
            for my $f (keys %paidfines){
                my $trans = {   accounttype => 'SYSTEM_CREDIT',
                                date        => $paidfines{$f}->{date},
                                description => $paidfines{$f}->{description},
                                amount      => -1 * $paidfines{$f}->{unhandled},
                            };
                if($paidfines{$f}->{accounttype} eq 'FFOR'){
                    $trans->{accounttype} = 'FORGIVE';
                } else {
                    $verbose and warn "Generating SYSTEM transaction to write off unhandled paidfine $f ";
                    push @logoutput,  "$borrowernumber\t$paidfines{$f}->{unhandled}\tSYSTEM transaction to write off unhandled paidfine $f\n";
                    $has_discrepancy=1;                    
                }

                C4::Accounts::ApplyCredit($paidfines{$f}->{fee_id}, $trans);
                delete $paidfines{$f};
                }
         } elsif($balance >= $totalowed - $applied_unallocated_payments_amt) {
             # We're closer; add SYSTEM fees to balance these payments.
            for my $payment (values %payments){
                next unless $payment->{payment_id};
                my $p = C4::Accounts::getpayment($payment->{payment_id}, unallocated=>1);
                if(exists $p->{unallocated} && $p->{unallocated}->{amount}){
                    push @logoutput,  "$borrowernumber\t$p->{unallocated}->{amount}\tADDING SYSTEM DEBIT to balance unhandled payment amount $p->{unallocated}->{amount} / $p->{amount} from payment_id $p->{id} \n";
                    $verbose and warn "ADDING SYSTEM DEBIT of amount $p->{unallocated}->{amount} from accountline $payment->{accountno} to equalize balance.";
                    $has_discrepancy=1;
                    my $trans = {   borrowernumber => $borrowernumber,
                                    accounttype => 'SYSTEM_DEBIT',
                                    timestamp        => $p->{date},
                                    description => $p->{description},
                                    amount      => -1 * $p->{unallocated}->{amount},
                                    notes       => sprintf("accountno:%d",$payment->{accountno}),
                            };                   
                    C4::Accounts::CreateFee($trans);
                }          
            }
         } else {
             $verbose and warn "FAIL.  You need yet another endgame strategy.";
         }
         

        # Here we COULD create a fee or credit to balance out, but I'll pass for now, and just let it log the discrepancies.   
        
        ## Lastly, clean up the account by redistributing credits.  (this would happen anyway the first time the account was viewed in staff interface)
        
        C4::Accounts::RedistributeCredits($borrowernumber);
        
        $totalowed = C4::Accounts::gettotalowed($borrowernumber);
        if(sprintf("%.2f",$totalowed) eq sprintf("%.2f",$balance)){
            $verbose and warn "SUCCESSFUL TRANSLATION TO NEW FEES STRUCTURE.";
        } else {
            $verbose and warn "!!!!!!!!!!  FAILURE  !!!!!!!!!!!! borrower $borrowernumber \n\t TOTALOWED: $totalowed  <==>  BALANCE: $balance";
            push @logoutput,  sprintf "%s\t%s\tDISCREPANCY --old/new balance: %s / %s\n", $borrowernumber, $totalowed-$balance, $balance, $totalowed;
            $has_discrepancy=1;
            $exit = 1 if $die;
        }
        my $unhandled = scalar(keys %paidfines) + scalar(keys %linked_writeoffs) + scalar(keys %unlinked_writeoffs) + scalar(keys %unknown);
        $unhandled += scalar(keys %debits);
        $unhandled += scalar(keys %credits) ;
            # ignore these errors, since if the amountoutanding is zero, then it got a SYSTEM transaction.
            # FIXME: This is no longer the case [2013]
                #  scalar(keys %unlinked_payments)+ scalar(keys %linked_payments) 
        if($unhandled){
           $verbose and warn "UNHANDLED accountlines: borrowernumber $borrowernumber \n\tFines: linked/paid: ".scalar(keys %paidfines) .
                        "\n\tlinked writeoffs: ".scalar(keys %linked_writeoffs).
                        "\n\tunlinked writeoffs: ".scalar(keys %unlinked_writeoffs).
                        "\n\tallocated payments: ".scalar(keys %payments).
                        "\n\toutstanding debits: ".scalar(keys %debits)."\n\toutstanding credits: ".scalar(keys %credits).
                        "\n\tunknown accounttypes: ".join(" \n ", p %unknown)."\n";
        }
        $num_bor_handled++;
        $discrepancies++ if $has_discrepancy;
        appendLog(join('',@logoutput)) if(scalar @logoutput > 0);
        last if $exit;
    }
    return $num_bor_handled;
        
} # /do_patron


