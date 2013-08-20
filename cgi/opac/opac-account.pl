#!/usr/bin/env perl

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

# wrriten 15/10/2002 by finlay@katipo.oc.nz
# script to display borrowers account details in the opac

use strict;
use CGI;
use C4::Members;
use C4::Accounts;
use C4::Circulation;
use C4::Auth;
use C4::Output;
use C4::Dates qw/format_date/;
use warnings;

my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-account.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

# get borrower information ....
my $borr = GetMemberDetails( $borrowernumber );
my @bordat;
$bordat[0] = $borr;

$template->param( BORROWER_INFO => \@bordat );

my $total = C4::Accounts::gettotalowed($borrowernumber);
my $totalaccruing = C4::Accounts::gettotalaccruing($borrowernumber);
my ($total_credits, $unallocated) = C4::Accounts::get_unallocated_credits( $borrowernumber );
foreach my $row (@$unallocated) {
    $row->{date} =  C4::Dates->new($row->{'date'},'iso')->output();
    $row->{'amount'} = as_currency($row->{'amount'});
}

my $fees = C4::Accounts::getcharges($borrowernumber, { outstanding => 1} );
for my $fee (@$fees) {
    C4::Accounts::prepare_fee_for_display($fee);
}

$template->param (
    ACCOUNT_LINES   => $fees,
    total           => $total,
    totalaccruing   => $totalaccruing,
    total_credits   => $total_credits || undef,
    unallocated     => $unallocated,
);



output_html_with_http_headers $query, $cookie, $template->output;

