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

my $input=new CGI;

my $borrowernumber=$input->param('borrowernumber');
my $superlibrarian=$input->param('superlibrarian');

#get borrower details
my $data=GetMember($borrowernumber,'borrowernumber');
my $refund=$input->param('refund');

my $authorized;
if ($superlibrarian) {
  my $authcode = C4::Auth::checkpw( C4::Context->dbh, $input->param('auth_username'), $input->param('auth_password'), 0, my $bypass_userenv = 1 );
  my $permissions = C4::Auth::haspermission( $input->param('auth_username'), { 'superlibrarian' => 1 } );
  if ( $authcode && $permissions ) {
    $authorized = 1;
  }
}

if ($refund){
    my $accountno=$input->param('accountno');
    my $itemnumber=$input->param('itemnumber');
    my $borrowernumber=$input->param('borrowernumber');
    C4::Accounts::refundlostitemreturned(
      borrowernumber => $borrowernumber,
      accountno      => $accountno,
      itemnumber     => $itemnumber,
    );
    print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
} else {
	my ($template, $loggedinuser, $cookie)
	  = get_template_and_user({template_name => "members/refund.tmpl",
					  query => $input,
					  type => "intranet",
					  authnotrequired => 0,
					  flagsrequired => {borrowers => '*', updatecharges => '*'},
					  debug => 1,
					  });

    my ($total, $accts) = C4::Accounts::MemberAllAccounts(borrowernumber=>$borrowernumber);
    my @accountrows;
    for (my $i = 0; $i < @$accts; $i++) {
      if ($accts->[$i]{'accounttype'} eq 'RCR') {
        $accts->[$i]{'amount'}            += 0.00;
        $accts->[$i]{'amountoutstanding'} += 0.00;
        my %row = (
          type           => "Refund",
          itemnumber     => $accts->[$i]{'itemnumber'},
          biblionumber   => $accts->[$i]{'biblionumber'},
          borrowernumber => $borrowernumber,
          accountno      => $accts->[$i]{'accountno'},
          title          => $accts->[$i]{'title'},
          amount         => sprintf('%.2f', $accts->[$i]{'amountoutstanding'}),
        );
        push(@accountrows, \%row);
      }
    }
					  
    if ($authorized) {
      $template->param(authorized => 1);
    }
    $template->param(
        refundtab      => 1,
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
}
