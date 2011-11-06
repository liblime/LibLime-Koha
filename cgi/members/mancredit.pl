#!/usr/bin/env perl

#written 11/1/2000 by chris@katipo.oc.nz
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
use CGI;

use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Items;
use Koha;
use C4::Context;

my $input=new CGI;

my $borrowernumber=$input->param('borrowernumber');
my ($template, $loggedinuser, $cookie)
	  = get_template_and_user({template_name => "members/mancredit.tmpl",
					  query => $input,
					  type => "intranet",
					  authnotrequired => 0,
					  flagsrequired => {borrowers => '*', updatecharges => '*'},
					  debug => 1,
					  });

#get borrower details
my $data=GetMember($borrowernumber,'borrowernumber');
if ($input->param('add')){
    C4::Accounts::manualinvoice(
      borrowernumber => $borrowernumber,
      itemnumber     => GetItemnumberFromBarcode($input->param('barcode')),
      description    => $input->param('desc'),
      amount         => -($input->param('amount') || 0),
      accounttype    => $input->param('type'),
      isCredit       => 1,
      user           => C4::Context->userenv->{'id'},
    );
    print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
} else {
    if ( $data->{'category_type'} eq 'C') {
        my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
        my $cnt = scalar(@$catcodes);
        $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
        $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
    }
					  
    $template->param( adultborrower => 1 ) if ( $data->{category_type} eq 'A' );
    my ($picture, $dberror) = GetPatronImage($data->{'cardnumber'});
    $template->param( picture => 1 ) if $picture;
    
    my $haveRefund = 0;
    my($total,$accts) = C4::Accounts::MemberAllAccounts(borrowernumber=>$borrowernumber);
    foreach(@$accts) {
       $$_{amountoutstanding} ||= 0;
       if (($$_{amountoutstanding} < 0) && ($$_{accounttype} eq 'RCR')) {
          $haveRefund = 1;
          last;
       }
    }
    $template->param(
        refundtab      => $haveRefund,
        borrowernumber => $borrowernumber,
        firstname => $data->{'firstname'},
        surname  => $data->{'surname'},
		    cardnumber => $data->{'cardnumber'},
		    categorycode => $data->{'categorycode'},
		    category_type => $data->{'category_type'},
		    categoryname  => $data->{'description'},
		    address => $data->{'address'},
		    address2 => $data->{'address2'},
		    city => $data->{'city'},
		    zipcode => $data->{'zipcode'},
		    country => $data->{'country'},
		    phone => $data->{'phone'},
		    email => $data->{'email'},
		    branchcode => $data->{'branchcode'},
		    branchname => GetBranchName($data->{'branchcode'}),
		    is_child        => ($data->{'category_type'} eq 'C'),
        );
    output_html_with_http_headers $input, $cookie, $template->output;
}
