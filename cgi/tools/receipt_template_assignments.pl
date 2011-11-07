#!/usr/bin/env perl

# Copyright 2011 Kyle M Hall <kyle@kylehall.info>
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
use Koha;
use C4::Context;
use C4::Output;
use C4::ReceiptTemplates;

my $input = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/receipt_template_assignments.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { tools => 'receipts_assign' },
    }
);

my $branchcode = C4::Context->userenv->{'branch'};

my @circulation_actions = (
    'check_in',              'check_out',
    'check_out_quick',       'not_found',
    'claims_returned_found', 'lost_item_found',
    'needs_cataloging'
);
my @holds_actions = ( 'hold_found', 'transit_hold' );
my @payment_actions = ('payment_received');

if ( $input->param('save_assignments') ) {
    foreach
      my $action ( @circulation_actions, @holds_actions, @payment_actions )
    {
        AssignReceiptTemplate(
            {
                action     => $action,
                branchcode => $branchcode,
                code       => $input->param($action),
            }
        );
    }

    $template->param( 'assignments_saved' => 1 );
}

my @actions_loop;

foreach my $action (@circulation_actions) {
    my %loop_iteration;

    my $current_template = GetAssignedReceiptTemplate(
        {
            branchcode => $branchcode,
            action     => $action,
        }
    );

    my $templates = GetReceiptTemplates(
        {
            branchcode => $branchcode,
            module     => 'circulation',
            selected   => $current_template,
        }
    );

    $loop_iteration{module_circulation} = 1;
    $loop_iteration{action}             = $action;
    $loop_iteration{select_loop}        = $templates;
    push( @actions_loop, \%loop_iteration );
}

foreach my $action (@holds_actions) {
    my %loop_iteration;

    my $current_template = GetAssignedReceiptTemplate(
        {
            branchcode => $branchcode,
            action     => $action,
        }
    );

    my $templates = GetReceiptTemplates(
        {
            branchcode => $branchcode,
            module     => 'holds',
            selected   => $current_template,
        }
    );

    $loop_iteration{module_holds} = 1;
    $loop_iteration{action}       = $action;
    $loop_iteration{select_loop}  = $templates;
    push( @actions_loop, \%loop_iteration );
}

foreach my $action (@payment_actions) {
    my %loop_iteration;

    my $current_template = GetAssignedReceiptTemplate(
        {
            branchcode => $branchcode,
            action     => $action,
        }
    );

    my $templates = GetReceiptTemplates(
        {
            branchcode => $branchcode,
            module     => 'payments',
            selected   => $current_template,
        }
    );

    $loop_iteration{module_payments} = 1;
    $loop_iteration{action}          = $action;
    $loop_iteration{select_loop}     = $templates;
    push( @actions_loop, \%loop_iteration );
}

$template->param( actions_loop => \@actions_loop );

output_html_with_http_headers $input, $cookie, $template->output;
