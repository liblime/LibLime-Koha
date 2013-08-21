#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Accounts;

my $input = new CGI;
my $dbh = C4::Context->dbh;

my $op = $input->param('op') || 'view';

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "admin/accounttypes.tmpl",
                            query => $input,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {parameters => 1},
                            debug => 1,
                            });

my $error;

if ($op eq 'delete') {
    my $accounttype = $input->param('accounttype');
    warn $accounttype;
    $error = C4::Accounts::del_accounttype($accounttype);
    warn $error;
    
} elsif ($op eq 'mod') {
    # Note we only allow add/mod of 'invoice' accounttypes.
    my $amt = ($input->param('default_amt')) ? $input->param('default_amt') : 0;
    my $atype = $input->param('accounttype');
    $atype =~ s/\s*$//;
    my $accounttype = { accounttype => $atype,
                        description => $input->param('description'),
                        default_amt => $amt,
    };
    $error = C4::Accounts::mod_accounttype($accounttype);
}

my $atypes = C4::Accounts::getaccounttypes();
my $fee_types = [ map { {accounttype => $_, description => $atypes->{$_}{description} } } keys %{C4::Accounts::getaccounttypes('fee')} ];
my $pay_types = [ map { {accounttype => $_, description => $atypes->{$_}{description} } } keys %{C4::Accounts::getaccounttypes('payment')} ];
my $invoice_types = [ map { {accounttype => $_, description => $atypes->{$_}{description}, default_amt => $atypes->{$_}{default_amt} } } keys %{C4::Accounts::getaccounttypes('invoice')} ];

for (@$invoice_types){
    $_->{can_delete} = C4::Accounts::can_del_accounttype($_->{accounttype});
}

$template->param(
    error           => $error,
    fee_types       => $fee_types,
    invoice_types   => $invoice_types,
    pay_types       => $pay_types,
);
output_html_with_http_headers $input, $cookie, $template->output;

exit 0;
