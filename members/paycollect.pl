#!/usr/bin/env perl
# Copyright 2009 PTFS
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
use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use CGI;
use C4::Members;
use C4::Accounts;
use C4::Koha;
use C4::Branch;
use C4::Dates;
use URI::Escape;

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => 'members/paycollect.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => '*', updatecharges => 1 },
        debug           => 1,
    }
);

my @names          = $input->param();
my $borrowernumber = $input->param('borrowernumber');

# get borrower details
my $data = GetMember( $borrowernumber, 'borrowernumber' );
my $user = C4::Context->userenv->{id};

# get account details
my $branches = GetBranches();
my $branch   = GetBranch( $input, $branches );

my($total_due,$accts) = C4::Accounts::MemberAllAccounts(borrowernumber=>$borrowernumber);
my $haveRefund = 0;
my $total_paid = $input->param('paid');
my $individual = $input->param('pay_individual');
my $writeoff   = $input->param('writeoff_individual');
my $accountno  = $input->param('accountno') || 0;
foreach(@$accts) {
   if (($$_{amountoutstanding} <0) && ($$_{accounttype} eq 'RCR')) {
      $haveRefund = 1;
   }

   if (($accountno == $$_{accountno}) && ( $individual || $writeoff )) {
      if ($individual) {
        $template->param( pay_individual => 1 );
      } elsif ($writeoff) {
        $template->param( writeoff_individual => 1 );
      }
      $total_due = $$_{amountoutstanding};
      $template->param(
        itemnumber        => $$_{itemnumber},
        biblionumber      => $$_{biblionumber},
        barcode           => $$_{barcode},
        accounttype       => $$_{accounttype},
        accountno         => $$_{accountno},
        amount            => sprintf('%.2f',$$_{amount}),
        amountoutstanding => sprintf('%.2f',$$_{amountoutstanding}),
        date              => $$_{date},
        title             => $$_{title},
        description       => $$_{description},
        notify_id         => $$_{notify_id},
        notify_level      => $$_{notify_level},
      );
   }
}
$template->param(refundtab => $haveRefund);

$total_due  = sprintf('%.2f',$total_due);
$total_paid = sprintf('%.2f',$total_paid);
if ( $total_paid and $total_paid ne '0.00' ) {
    if (( $total_paid <= 0) or ($total_paid > $total_due )) {
        $template->param(
            error => "You must pay a value less than or equal to $total_due" );
    } else {
        if ($individual) {
            if ( $total_paid == $total_due ) {
                makepayment( $borrowernumber, $accountno, $total_paid, $user,
                    $branch );
            } else {
                makepartialpayment( $borrowernumber, $accountno, $total_paid,
                    $user, $branch );
            }
            print $input->redirect(
                "/cgi-bin/koha/members/pay.pl?borrowernumber=$borrowernumber" );
        } else {
            recordpayment( $borrowernumber, $total_paid );

# recordpayment does not return success or failure so lets redisplay the boraccount
            print $input->redirect(
"/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber"
            );
        }
    }
} else {
    $total_paid = '0.00';    #TODO not right with pay_individual
}
if ( $data->{category_type} eq 'C' ) {
    my ( $catcodes, $labels ) =
      GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
    my $cnt = scalar @{$catcodes};
    if ( $cnt == 1 ) {
        $template->param( 'catcode' => $catcodes->[0] );
    } elsif ( $cnt > 1 ) {
        $template->param( 'CATCODE_MULTI' => 1 );
    }
}

if ( $data->{'category_type'} eq 'A' ) {
    $template->param( adultborrower => 1 );
}
my ( $picture, $dberror ) = GetPatronImage( $data->{'cardnumber'} );
if ($picture) {
    $template->param( picture => 1 );
}

$template->param(
    firstname      => $data->{firstname},
    surname        => $data->{surname},
    borrowernumber => $borrowernumber,
    cardnumber     => $data->{cardnumber},
    categorycode   => $data->{categorycode},
    category_type  => $data->{category_type},
    categoryname   => $data->{description},
    address        => $data->{address},
    address2       => $data->{address2},
    city           => $data->{city},
    zipcode        => $data->{zipcode},
    phone          => $data->{phone},
    email          => $data->{email},
    branchcode     => $data->{branchcode},
    branchname     => GetBranchName( $data->{branchcode} ),
    is_child       => ( $data->{category_type} eq 'C' ),
    total          => sprintf( '%.2f', $total_due ),
);
output_html_with_http_headers $input, $cookie, $template->output;
