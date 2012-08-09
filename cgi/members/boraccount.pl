#!/usr/bin/env perl


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
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Dates;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Accounts;
use Koha::Money;

my $input=new CGI;

my ($template, $loggedinuser, $cookie, $staffflags)
    = get_template_and_user({template_name => "members/boraccount.tmpl",
                            query => $input,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {borrowers => "borrowers_remaining_permissions", updatecharges => 1},
                            debug => 1,
                            });

my $op = $input->param('op');
my $borrowernumber=$input->param('borrowernumber');
#get borrower details
my $data   = GetMember($borrowernumber,'borrowernumber');
#my %atypes = C4::Accounts::_get_accounttypes();
my $atypes = C4::Accounts::getaccounttypes();

# disallow unprivileged staff to update fines, while allowing those with
# 'borrowers' permission to view account and account history.
# Note this doesn't really work with the left-hand tabs, but there are links to
# boraccount.pl in moremember ( FIXME ).
$op = '' unless( $op eq 'history' || $staffflags->{'superlibrarian'} || $staffflags->{'updatecharges'} );
my $error;
my @fees_to_pay = undef;

my $borcat = C4::Members::GetCategoryInfo($data->{categorycode});


if($op eq 'maninvoice'){
    # FIXME : test for accounttypes which should actually be allowed to attach to an item.
    my $barcode=$input->param('barcode');
    my $item = GetItemnumberFromBarcode($barcode) if $barcode;
    my $amount = $input->param('amount') || 0;
    
    if($barcode && !$item){
        $error = 'INVALID_BARCODE';
    } elsif( $amount <= 0 ){
        $error = 'INVALID_AMOUNT';
    } else {
        my $invoice = { 
                borrowernumber  => $borrowernumber,
                description     => $input->param('desc'),
                amount          => sprintf("%.2f",$amount),
                accounttype     => $input->param('accounttype'),
                operator_id     => $loggedinuser,
            };
        $invoice->{itemnumber} = $item if($item);
        $error = manualinvoice($invoice);
    }
} elsif($op eq 'mancredit'){
    # Create credit.  Will be applied to fees when RedistributeCredits is called.
    my $credit = {
                borrowernumber  => $borrowernumber,
                description     => $input->param('desc'),
                amount          => sprintf("%.2f",$input->param('amount')),
                accounttype     => $input->param('accounttype'),
                operator_id     => $loggedinuser,
            };
    @fees_to_pay = map { $_ + 0 } $input->param('fees_to_pay');
    $error = (@fees_to_pay) ? manualcredit($credit, fees => \@fees_to_pay) : manualcredit($credit);
} elsif($op eq 'pay'){
    my $fee_id = $input->param('fee_id');
    my $desc = $input->param('desc');
    my $amt = Koha::Money->new(sprintf("%.2f",$input->param('amount')));
    my $payment = { accounttype => 'PAYMENT',
                    amount      => -1 * $amt,
                    description => $desc,
    };
    $error = C4::Accounts::ApplyCredit( $fee_id, $payment);
} elsif($op eq 'forgive'){
    my $fee_id = $input->param('fee_id');
    my $notes = $input->param('desc');
    my $amt = Koha::Money->new(sprintf("%.2f",$input->param('amount')));
    my $accttype = ($input->param('forgivetype') eq 'writeoff') ? 'WRITEOFF' : 'FORGIVE';
    my $payment = { accounttype => $accttype,
                    amount      => -1 * $amt,
                    notes => $notes,
    };
    $error = C4::Accounts::ApplyCredit( $fee_id, $payment);
} elsif($op eq 'forgive_many'){
    my $accttype = ($input->param('forgivetype') eq 'writeoff') ? 'WRITEOFF' : 'FORGIVE';
    my $notes = $input->param('desc');  # Yes, this is sloppy.
    my @fees_to_pay = split(',',$input->param('fee_id'));
    if(scalar @fees_to_pay){
        C4::Accounts::ApplyCredit( $_, { accounttype => $accttype, notes => $notes }) for @fees_to_pay;
    } else {
        for (@{C4::Accounts::getcharges( $borrowernumber, outstanding=>1)}){
            C4::Accounts::ApplyCredit( $_->{fee_id}, { accounttype => $accttype, notes => $notes });
        }        
    }

} elsif($op eq 'send_alert'){
    #FIXME: This block never happens in LK. (see comment below)
	# pass...
	
} elsif($op eq 'reverse'){
    my $pay_id = $input->param('id');
    my $payment = C4::Accounts::getpayment($pay_id);
    if($payment->{borrowernumber} == $borrowernumber){
        $error = C4::Accounts::reverse_payment($pay_id);
    } else {
        $error = 'INVALID_PAYMENT_ID';
    }
    warn $error;
} elsif($op eq 'refund'){
    my @pay_id = $input->param('id');
    my $amount = Koha::Money->new(sprintf("%.2f",$input->param('amount')));
    if($amount < 0.0){
        my $fee_id = C4::Accounts::CreateFee({
                borrowernumber => $borrowernumber,
                amount         => -1 * $amount,
                accounttype    => 'REFUND',
                description    => 'Refund issued.',   # FIXME: Add more information here.
        });
        my $refunded_amt = Koha::Money->new();
        if(scalar @pay_id > 0){
            for (@pay_id){
                my $payment = C4::Accounts::getpayment($_, unallocated=>1);
                $refunded_amt += $payment->{unallocated}->{amount};
                C4::Accounts::allocate_payment(fee=>$fee_id, payment=>$payment);
            }
        } else {
            # refund Full.
            # RedistributeCredits should handle things below...
            # But we don't bother error checking as above.
            $refunded_amt = $amount;  #(cheat)
        }
        $error = 'ACCOUNT_BALANCE_CHANGED_DURING_REQUEST' if($refunded_amt != $amount);
    } else {
        $error = 'INVALID_REFUND_AMOUNT';
    }

}
# We call RedistributeCredits regardless of how this script is invocated.
# This ensures that any unallocated credits are applied to outstanding fees.
C4::Accounts::RedistributeCredits( $borrowernumber );
my @currentfees;
my @payablefees;
my @history;

my $accruingfees = C4::Accounts::getaccruingcharges( $borrowernumber );
for my $fee (@{C4::Accounts::getcharges( $borrowernumber )}){
    C4::Accounts::prepare_fee_for_display($fee);
    if($fee->{amountoutstanding} > 0){
        # currentfees shows summary of outstanding fees.
        push(@currentfees, $fee);
        push(@payablefees, $fee);
    }
    my $credits = C4::Accounts::getcredits( $fee->{id} );
    if(scalar(@$credits)){
        # Display a summary of payments/credits for this fee.
        $fee->{'has_credit'} = 1;
        foreach (@$credits) { 
            $_->{'accounttype_desc'} = $atypes->{$_->{accounttype}}->{description};
        };
        $fee->{'creditloop'} = $credits;
    }
    push(@history, $fee);
}
for my $fee (@$accruingfees){
    C4::Accounts::prepare_fee_for_display($fee);
    push @currentfees, $fee;
}
my ($total_credits, $unallocated) = C4::Accounts::get_unallocated_credits( $borrowernumber );
foreach my $row (@$unallocated) {
    $row->{date} =  C4::Dates::format_date($row->{'timestamp'});
    $row->{amount} = sprintf("%.2f",$row->{'amount'}->value);
    $row->{payment_amount} = sprintf("%.2f",$row->{'payment_amount'}->value);
}

my $allpayments = C4::Accounts::getpayments($borrowernumber);
for (@$allpayments){
    $_->{isodate} = C4::Dates::format_date($_->{date},'iso');
    $_->{date} = C4::Dates::format_date($_->{date});
    $_->{payment} = 1;
    $_->{accounttype_desc} = $atypes->{$_->{accounttype}}->{description};
    $_->{amount} = sprintf("%.2f", $_->{amount}->value);
    $_->{is_reversed} = C4::Accounts::is_reversed($_);
    push @history, $_;
}
my @sorted_history = sort { $b->{isodate} cmp $a->{isodate} || {($b->{payment}) ? 1 : 0 <=> ($a->{payment}) ? 1 : 0 } || $b->{transaction_id} <=> $a->{transaction_id} } @history;
# FIXME: This still has payments beneath fines on the same day.

# display account summary, regardless of $op.

my $totaldue = C4::Accounts::gettotalowed($borrowernumber);
my $totalaccruing = C4::Accounts::gettotalaccruing($borrowernumber);
# FIXME: deprecate this vvv
my $totaloverpayments = C4::Accounts::get_total_overpaid($borrowernumber);
my @invoice_types;
my @fee_types;

# Below doesn't work on LK since different branches can have different billing notices, 
# defined only in cron script arguments.  TODO: move that to the branches table.
#my $last_fines_alert = C4::Message->find_last_message($data, 'BILLING', transport => 'email', include_sent => 1); 
#my $last_fines_alert_date = $last_fines_alert && C4::Dates->new($last_fines_alert->{time_queued}, 'iso')->output();
#my $over_alert_threshold = Koha::Money->new( $borcat->{fines_alert_threshold}) > 0.01 && Koha::Money->new( $totaldue) >= $borcat->{fines_alert_threshold};

for my $inv_type ( C4::Accounts::getaccounttypes('fee') ){
    # these accounttypes should be properly linked to credits.
    next if($inv_type eq 'CANCELCREDIT' || $inv_type eq 'REVERSED_PAYMENT');
    push @fee_types, { accounttype => $inv_type , description => $atypes->{$inv_type}->{'description'} };
}
for my $inv_type ( C4::Accounts::getaccounttypes('invoice') ){
    push @invoice_types, { accounttype => $inv_type , description => $atypes->{$inv_type}->{'description'}, default_amt => $atypes->{$inv_type}->{default_amt} };
}
# FIXME : this template stuff has to go in every page -- should just be able to call a function.
$template->param( adultborrower => 1 ) if ( $data->{'category_type'} eq 'A' );

my ($picture, $dberror) = GetPatronImage($data->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

my @payment_types;
for my $pay_type (sort {$a cmp $b} C4::Accounts::getaccounttypes('payment')){
    my $option = { accounttype => $pay_type , description => $atypes->{$pay_type}->{'description'} };
    $option->{selected} = 1 if($pay_type eq 'PAYMENT');
    push @payment_types, $option;
}


$template->param(
    firstname           => $data->{'firstname'},
    surname             => $data->{'surname'},
    borrowernumber      => $borrowernumber,
    cardnumber          => $data->{'cardnumber'},
    categorycode        => $data->{'categorycode'},
    category_type       => $data->{'category_type'},
    is_child        => ($data->{'category_type'} eq 'C'),
    categoryname		 => $data->{'description'},
    address             => $data->{'address'},
    address2            => $data->{'address2'},
    city                => $data->{'city'},
    zipcode             => $data->{'zipcode'},
    country             => $data->{'country'},
    phone               => $data->{'phone'},
    email               => $data->{'email'},
    branchcode          => $data->{'branchcode'},
	branchname			=> GetBranchName($data->{'branchcode'}),
    has_current_fees    => scalar(@currentfees),
    has_unallocated     => ($total_credits < 0) ? 1 : 0,
    total               => sprintf("%.2f",$totaldue),
    totalaccruing       => sprintf("%.2f",$totalaccruing),
    totalcredit         => ($totaldue >= 0 ) ? 0 : 1,
    no_history          => (scalar(@history) > 0) ? 0 : 1,
    fee_types           => \@fee_types,
    invoice_types       => \@invoice_types,
    payment_types       => \@payment_types,
    currentfees         => \@currentfees,
    payablefees         => \@payablefees,
    has_payable         => scalar(@payablefees),
    unallocated         => $unallocated,
    account_history     => \@sorted_history,
    ERROR               => $error,
    'ERROR_'.$error     => 1,
    UseReceiptTemplates => C4::Context->preference('UseReceiptTemplates'),
    
#    over_alert_threshold => $totaldue >= $borcat->{fines_alert_threshold},
#    fines_alert_threshold => Koha::Money->new($borcat->{fines_alert_threshold})->as_string(),
#    last_fines_alert_date => $last_fines_alert_date->output(),
#    alerted_today        => $last_fines_alert_date == C4::Dates->new(),
    
    );

output_html_with_http_headers $input, $cookie, $template->output;

