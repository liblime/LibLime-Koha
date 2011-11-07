#!/usr/bin/env perl

# Copyright 2011 PTFS/LibLime
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
use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Items;
use Koha;
use C4::Context;
use CGI;

my $input = CGI->new();
my ($template, $loggedinuser, $cookie)
	  = get_template_and_user({template_name => "members/refund.tmpl",
					  query => $input,
					  type => "intranet",
					  authnotrequired => 0,
					  flagsrequired => {borrowers => '*', updatecharges => '*'},
					  debug => 1,
					  });
my $borrowernumber = $input->param('borrowernumber');
my $superlibrarian = $input->param('superlibrarian');
my $data           = GetMember($borrowernumber,'borrowernumber');
my $authorized     = 0;
my $showForm       = 0;

if ($superlibrarian) {
  my $authcode = C4::Auth::checkpw( C4::Context->dbh, $input->param('auth_username'), $input->param('auth_password'), 0, my $bypass_userenv = 1 );
  my $permissions = C4::Auth::haspermission( $input->param('auth_username'), { 'superlibrarian' => 1 } );
  if ( $authcode && $permissions ) {
    $authorized = 1;
  }
}
else {
   $showForm = 1 if !!$template->{param_map}->{CAN_user_updatecharges_refund_charges};
}
$showForm ||= $authorized;

if ($input->param('refundBalance')){
   C4::Accounts::refundBalance(borrowernumber => $borrowernumber);
   print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
   exit;
}
elsif ($input->param('accountno')) {
   C4::Accounts::RCR2REF(
      borrowernumber=>$borrowernumber,
      accountno     =>$input->param('accountno'),
   );
}
my ($total, $accts) = C4::Accounts::MemberAllAccounts(borrowernumber=>$borrowernumber);
if ($total >= 0) {
   print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
   exit;
}

my @accountrows;
my $refundSubtotal = 0;
my $lineitem       = C4::Context->preference('RefundLostReturnedAmount');
foreach(@$accts) {
   next unless $$_{amountoutstanding}<0;
   next unless $$_{accounttype} eq 'RCR';
   $refundSubtotal += $$_{amountoutstanding};
   push(@accountrows, {
      itemnumber     => $$_{'itemnumber'},
      biblionumber   => $$_{'biblionumber'},
      borrowernumber => $borrowernumber,
      accountno      => $$_{'accountno'},
      title          => $$_{'title'},
      barcode        => $$_{barcode},
      description    => $$_{description},
      amount         => sprintf('%.2f', $$_{'amountoutstanding'}),
      refundBtn      => (($$_{amountoutstanding} >= $total) && $lineitem)? 1:0,
   });
}

$template->param(
        showForm       => $showForm,
        authorized     => $authorized,
        refundtab      => 1,
        refundSubtotal => sprintf('%.2f',$refundSubtotal),
        accountBalance => sprintf('%.2f',$total),
        otherCharges   => sprintf('%.2f',$total - $refundSubtotal),
        refundAmount   => ($total<0)? sprintf('%.2f',-1 *$total) : 0,
        borrowernumber => $borrowernumber,
        firstname      => $data->{'firstname'},
        surname        => $data->{'surname'},
        cardnumber     => $data->{'cardnumber'},
        categorycode   => $data->{'categorycode'},
        category_type  => $data->{'category_type'},
        categoryname   => $data->{'description'},
        address        => $data->{'address'},
        address2       => $data->{'address2'},
        city           => $data->{'city'},
        zipcode        => $data->{'zipcode'},
        phone          => $data->{'phone'},
        email          => $data->{'email'},
        branchcode     => $data->{'branchcode'},
        branchname     => GetBranchName($data->{'branchcode'}),
        accounts       => \@accountrows,
);
output_html_with_http_headers $input, $cookie, $template->output;
exit;

__END__

