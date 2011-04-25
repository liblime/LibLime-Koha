#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
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

use strict;
use warnings;

use CGI;

use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Koha;
use C4::Members;
use C4::Members::Lists;

my $input = new CGI;
my $list_id = $input->param('list_id');
my $confirmed = $input->param('confirmed');

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/member_lists_bulkedit_confirm.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
    }
);

my @actions;
my $i = 1;
while ( defined $input->param("field_$i") ) {
    my $action;
    $action->{'index'} = $i;
    $action->{'field'} = $input->param("field_$i");
    $action->{'old_value'} = $input->param("old_value_$i");
    $action->{'new_value'} = $input->param("new_value_$i");
    $action->{'delete'} = $input->param("delete_$i");
    
    push( @actions, $action );
    
    $i++;
}

my $members = GetListMembers({ list_id => $list_id });

my $members_updated;
my $members_deleted;
my $members_deleted_failed;
my $members_modified;

foreach my $m ( @$members ) {
    foreach my $a ( @actions ) {
        if ( $m->{ $a->{'field'} } eq $a->{'old_value'} ) {
            if ( $a->{'delete'} ) {
                $m->{'member_deleted'} = 1;

                my ($overdue_count, $issue_count, $total_fines) 
                    = GetMemberIssuesAndFines( $m->{'borrowernumber'} );
                    
                if ( $issue_count || $total_fines ) {
                    $m->{'member_deleted_failure'} = 1;
                                        
                    $m->{'member_deleted_failure_issues'} = 1 if ( $issue_count );
                    $m->{'member_deleted_failure_fines'}  = 1 if ( $total_fines );

                    $members_deleted_failed->{ $m->{'borrowernumber'} } = 1;
                } else {
                    $members_deleted->{ $m->{'borrowernumber'} } = 1;
                }
                
                if ( $confirmed && !$m->{'member_deleted_failure'} ) {
                    MoveMemberToDeleted( $m->{'borrowernumber'} );
                    DelMember( $m->{'borrowernumber'} );                
                }
                
            } else {
                $m->{ $a->{'field'} } = $a->{'new_value'};
                $m->{ $a->{'field'} . "_altered" } = 1;
                $m->{'member_updated'} = 1;
                $members_updated->{ $m->{'borrowernumber'} } = 1;
                
                if ( $confirmed ) {
                    ModMember(
                        borrowernumber => $m->{'borrowernumber'},
                        $a->{'field'} => $a->{'new_value'}
                    );
                }
            }
            
            $members_modified->{ $m->{'borrowernumber'} } = 1;
        }
    }
}

$template->param(
    MembersCount => scalar @$members,
    MembersDeleted => scalar keys %$members_deleted,
    MembersDeletedFailed => scalar keys %$members_deleted_failed,
    MembersUpdated => scalar keys %$members_updated,
    MembersModified => scalar keys %$members_modified,
    
    list_id => $list_id,
    confirmed => $confirmed
);

$template->param( 
    BorrowersLoop => $members,
    ActionsLoop => \@actions,
);

my $list = GetList({ list_id => $list_id });
$template->param( %$list );

output_html_with_http_headers $input, $cookie, $template->output;
