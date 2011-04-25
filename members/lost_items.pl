#!/usr/bin/perl

# Copyright 2000-2009 LibLime
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
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


=head1 lost_items.pl

Script to manage a patron's lost items

=cut

use strict;

use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Dates qw(format_date_in_iso);
use C4::LostItems qw(GetLostItem GetLostItems DeleteLostItem);
use Date::Calc qw(Today Date_to_Days);
use C4::Branch qw(GetBranchName);

my $query = new CGI;
my $debug;

my $op = $query->param("op");
my $borrowernumber = $query->param("borrowernumber");
my $lost_item_id = $query->param("lost_item_id");
my $borrower = GetMemberDetails( $borrowernumber, 0 );

my ($template, $loggedinuser, $cookie)
    = get_template_and_user(
        {template_name => "members/lost_items.tmpl",
           query => $query,
           type => "intranet",
           authnotrequired => 0,
           flagsrequired => {borrowers => "borrowers_remaining_permissions"},
           debug => ($debug) ? 1 : 0,
       });

if ($op and $op eq 'delete') {
    DeleteLostItem($lost_item_id);
    print $query->redirect("/cgi-bin/koha/members/lost_items.pl?borrowernumber=$borrowernumber");
    exit;
}
else {
    my $lost_items = GetLostItems($borrowernumber);
    for my $lost_item (@$lost_items) {
    }

    $template->param(LOST_ITEMS=> $lost_items);
    $template->param(borrowernumber => $borrowernumber);
}

$template->param(
    proxyview => 1,
    firstname => $borrower->{firstname},
    surname => $borrower->{surname},
);

# More template params for circ-menu.inc
# Fixme: these should be in a tmpl loop since we prepare them for seven different pages now.
$template->param(   cardnumber      => $borrower->{'cardnumber'},
                    categorycode    => $borrower->{'categorycode'},
                    category_type   => $borrower->{'category_type'},
                    categoryname    => $borrower->{'description'},
                    address         => $borrower->{'address'},
                    address2        => $borrower->{'address2'},
                    city            => $borrower->{'city'},
                    zipcode         => $borrower->{'zipcode'},
                    phone           => $borrower->{'phone'},
                    email           => $borrower->{'email'},
                    branchcode      => $borrower->{'branchcode'},
                    is_child        => ($borrower->{'category_type'} eq 'C'),
                    branchname      => GetBranchName($borrower->{'branchcode'}),
                    );
output_html_with_http_headers $query, $cookie, $template->output;
