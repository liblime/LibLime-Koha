#!/usr/bin/env perl


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

use CGI;

use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Members::Lists;

my $input = new CGI;
my $op = $input->param('op');

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/member_lists.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
    }
);

if ( $op eq 'create' ) {
    CreateList({ list_name => $input->param('list_name') });
} elsif ( $op eq 'delete' ) {
    DeleteList({ list_id => $input->param('list_id') });
} elsif ( $op eq 'add_to_list' ) {
    my $member = $input->param('member');
    my $list_id = $input->param('list_id');
    
    my ($count, $borrowers) = SearchMember( $member, 'surname,firstname' );
    
    if ( $count == 1 ) { ## Found the borrower, add to list
        my $borrower = @$borrowers[0];
        my $borrowernumber = $borrower->{'borrowernumber'};
        AddBorrowerToList({
            list_id => $list_id,
            borrowernumber => $borrowernumber
        });
        
        $template->param(
            borrower_cardnumber => $borrower->{'cardnumber'},
            borrower_surname => $borrower->{'surname'},
            borrower_firstname => $borrower->{'firstname'}
        );
        
    } elsif ( $count > 1 ) { ## Found multiple borrowers, displays select
        $template->param( BorrowersLoop => $borrowers );    
        
    } else { ## Found no borrowers
        $template->param( NoBorrowersFound => 1 );    
    }
}

$template->param( 
    ListsLoop => GetLists({ 
        with_count => 1,
        selected => $input->param('list_id'),
    }) 
);

output_html_with_http_headers $input, $cookie, $template->output;
