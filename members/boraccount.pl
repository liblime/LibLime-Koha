#!/usr/bin/env perl


#writen 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details


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
use warnings;

use C4::Auth;
use C4::Output;
use C4::Dates qw/format_date/;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::ReceiptTemplates;

my $input=new CGI;


my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/boraccount.tmpl",
                            query => $input,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {borrowers => '*', updatecharges => '*'},
                            debug => 1,
                            });

my $borrowernumber=$input->param('borrowernumber');
my $action = $input->param('action') || '';

#get borrower details
my $data=GetMember($borrowernumber,'borrowernumber');

if ( $action eq 'reverse' ) {
  ReversePayment( $borrowernumber, $input->param('accountno') );
}

if ( $data->{'category_type'} eq 'C') {
   my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
   my $cnt = scalar(@$catcodes);
   $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
   $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}

#get account details
my ($total,$accts) = C4::Accounts::MemberAllAccounts(borrowernumber=>$borrowernumber);
my @accountrows; # this is for the tmpl-loop

for (my $i=0;$i<@$accts;$i++) {
    $accts->[$i]{'amount'}+=0.00;
    if($accts->[$i]{'amount'} <= 0){
        $accts->[$i]{'amountcredit'} = 1;
    }
    $accts->[$i]{'amountoutstanding'}+=0.00;
    if($accts->[$i]{'amountoutstanding'} <= 0){
        $accts->[$i]{'amountoutstandingcredit'} = 1;
    }
    my %row = ( 'date'              => format_date($accts->[$i]{'date'}),
                'amountcredit'      => $accts->[$i]{'amountcredit'},
                'amountoutstandingcredit' => $accts->[$i]{'amountoutstandingcredit'},
                'toggle'            => ($i%2)? 0:1,
                'description'       => $accts->[$i]{'description'},
                'amount'            => sprintf("%.2f",$accts->[$i]{'amount'}),
                'amountoutstanding' => sprintf("%.2f",$accts->[$i]{'amountoutstanding'}),
                'accountno'         => $accts->[$i]{'accountno'},
                'payment'           => ( $accts->[$i]{'accounttype'} eq 'Pay' ),
                'itemnumber'        => $$accts[$i]{itemnumber},
                'biblionumber'      => $$accts[$i]{biblionumber},
                'title'             => $$accts[$i]{title},
                'barcode'           => $$accts[$i]{barcode},
                );
    
    $template->param( refundtab => 1 ) 
      if (($accts->[$i]{'accounttype'} eq 'RCR') 
       && ($accts->[$i]{'amountoutstanding'} < 0.0));
    push(@accountrows, \%row);
}

$template->param( adultborrower => 1 ) if ( $data->{'category_type'} eq 'A' );

my ($picture, $dberror) = GetPatronImage($data->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

$template->param(
    finesview           => 1,
    firstname           => $data->{'firstname'},
    surname             => $data->{'surname'},
    borrowernumber      => $borrowernumber,
    cardnumber          => $data->{'cardnumber'},
    categorycode        => $data->{'categorycode'},
    category_type       => $data->{'category_type'},
 #   category_description => $data->{'description'},
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
    total               => sprintf("%.2f",$total),
	is_child        => ($data->{'category_type'} eq 'C'),
    accounts            => \@accountrows ,

    UseReceiptTemplates => C4::Context->preference("UseReceiptTemplates"),
    UseReceiptTemplates_PaymentReceived => GetAssignedReceiptTemplate({ action => 'payment_received', branchcode => C4::Context->userenv->{'branch'} }),
    );

output_html_with_http_headers $input, $cookie, $template->output;
