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

my $input       = new CGI;
my $searchfield = $input->param('searchfield');
my $script_name = '/cgi-bin/koha/tools/receipt_template_manager.pl';

my $code    = $input->param('code');
my $module  = $input->param('module');
my $content = $input->param('content');

my $op = $input->param('op');

if ( !defined $module ) {
    $module = q{};
}

our $template;
my $borrowernumber;
my $cookie;
( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/receipt_template_manager.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { tools => 'receipts_manage' },
    }
);

if ( !defined $op ) {
    $op = q{};    # silence errors from eq
}

# we show only the TMPL_VAR names $op

$template->param(
    script_name => $script_name,
    action      => $script_name
);

if ( $op eq 'add_form' ) {
    add_form( $module, $code );
}
elsif ( $op eq 'add_validate' ) {
    add_validate($input);
    $op = q{};    # next operation is to return to default screen
}
elsif ( $op eq 'delete_confirm' ) {
    delete_confirm( $module, $code );
}
elsif ( $op eq 'delete_confirmed' ) {
    delete_confirmed( $module, $code );
    $op = q{};    # next operation is to return to default screen
}
else {
    default_display();
}

# Do this last as delete_confirmed resets
if ($op) {
    $template->param( $op => 1 );
}
else {
    $template->param( no_op_set => 1 );
}

output_html_with_http_headers $input, $cookie, $template->output;

sub add_form {
    my ( $module, $code ) = @_;

    my $receipt_template;

    # if code has been passed we can identify letter and its an update action
    if ($code) {
        $receipt_template = GetReceiptTemplate(
            {
                module     => $module,
                code       => $code,
                branchcode => C4::Context->userenv->{'branch'},
            }
        );

        $template->param( modify => 1 );
        $template->param( code   => $receipt_template->{code} );
    }
    else {    # initialize the new fields
        $receipt_template = {
            module  => $module,
            code    => q{},
            name    => q{},
            content => q{},
        };
        $template->param( adding => 1 );
    }

    # build field list
    my $field_selection;

    if ( $module eq 'holds' ) {
        ## Nothing to Add
    }
    elsif ( $module eq 'payments' ) {
        push @{$field_selection},
          (
            {
                value => 'TotalOwed',
                text  => 'TotalOwed',
            },
            {
                value => 'BeginTodaysPaymentsList',
                text  => 'BeginTodaysPaymentsList',
            },
            {
                value => 'EndTodaysPaymentsList',
                text  => 'EndTodaysPaymentsList',
            },
            {
                value => 'BeginRecentFinesList',
                text  => 'BeginRecentFinesList',
            },
            {
                value => 'EndRecentFinesList',
                text  => 'EndRecentFinesList',
            }
          );
    }
    else {    ## if ( $module eq 'circulation' ) {
        push @{$field_selection},
          (
            {
                value => 'BeginTodaysIssuesList',
                text  => 'BeginTodaysIssuesList',
            },
            {
                value => 'EndTodaysIssuesList',
                text  => 'EndTodaysIssuesList',
            },
            {
                value => 'BeginPreviousIssuesList',
                text  => 'BeginPreviousIssuesList',
            },
            {
                value => 'EndPreviousIssuesList',
                text  => 'EndPreviousIssuesList',
            }
          );
    }

    ## Add utility variables
    push @{$field_selection},
        (
            {
                value => '',
                text => '---UTILITY VARIABLES---',
            },
            {
                value => 'CURRENT_DATE',
                text => 'Current Date',
            },
        );

    if ( $module eq 'holds' ) {
        push @{$field_selection},
          add_fields(
            'branches',
            'biblio',
            'biblioitems',
            'items',
            'borrowers',
            'issues',
            'reserves',
            { table => 'branches', name => 'recieving_branch' }
          );
    }
    if ( $module eq 'payments' ) {

        push @{$field_selection},
          add_fields(
            'branches', 'borrowers'
          );
        push @{$field_selection},
           {
                value => '',
                text => '---FEES & PAYMENTS---',
            };
        push @{$field_selection},
            map { { value=> 'fees-payments.'.$_, text=> 'fees-payments.'.$_} } ('date', 'amount','amountoutstanding','description','accounttype');
            # fees-payments is taken from output of getcharges and getpayments in C4::Accounts.

    }
    else {    #if ($module eq 'circulation')
        push @{$field_selection},
          add_fields(
            'branches',  'biblio', 'biblioitems', 'items',
            'borrowers', 'issues'
          );
    }

    $template->param(
        name         => $receipt_template->{name},
        title        => $receipt_template->{title},
        content      => $receipt_template->{content},
        $module      => 1,
        SQLfieldname => $field_selection,
    );
    return;
}

sub add_validate {
    my $input = shift;
    my $module  = $input->param('module');
    my $code    = $input->param('code');
    my $name    = $input->param('name');
    my $content = $input->param('content');

    SetReceiptTemplate(
        {
            module     => $module,
            code       => $code,
            branchcode => C4::Context->userenv->{'branch'},
            name       => $name,
            content    => $content,
        }
    );

    # set up default display
    default_display();
    return;
}

sub delete_confirm {
    my ( $module, $code ) = @_;

    my $receipt_template = GetReceiptTemplate(
        {
            module     => $module,
            code       => $code,
            branchcode => C4::Context->userenv->{'branch'},
        }
    );

    $template->param( code   => $code );
    $template->param( module => $module );
    $template->param( name   => $receipt_template->{name} );
    return;
}

sub delete_confirmed {
    my ( $module, $code ) = @_;

    DeleteReceiptTemplate(
        {
            module     => $module,
            code       => $code,
            branchcode => C4::Context->userenv->{'branch'},
        }
    );

    # setup default display for screen
    default_display();
    return;
}

sub default_display {
    $template->param(
        receipts_loop => GetReceiptTemplates(
            { branchcode => C4::Context->userenv->{'branch'} }
        )
    );
    return;
}

sub add_fields {
    my @tables = @_;
    my @fields = ();

    for my $table (@tables) {
        my $name;
        if ( ref($table) eq "HASH" ) {
            $name  = $table->{'name'};
            $table = $table->{'table'};
        }

        push @fields, get_columns_for( $table, $name );

    }
    return @fields;
}

sub get_columns_for {
    my ( $table, $name ) = @_;

    # FIXME untranslateable
    my %column_map = ( reserves => '---HOLDS---', );
    my @fields = ();
    if ( exists $column_map{$table} ) {
        push @fields,
          {
            value => q{},
            text  => $column_map{$table},
          };
    }
    else {
        my $tlabel = '---' . uc $table;
        $tlabel .= '---';
        push @fields,
          {
            value => q{},
            text  => $tlabel,
          };
    }

    my $sql          = "SHOW COLUMNS FROM $table";    # TODO not db agnostic
    my $table_prefix = $table . q|.|;
    $table_prefix = $name . q|.| if ($name);
    my $rows = C4::Context->dbh->selectall_arrayref( $sql, { Slice => {} } );
    for my $row ( @{$rows} ) {
        push @fields,
          {
            value => $table_prefix . $row->{Field},
            text  => $table_prefix . $row->{Field},
          };
    }        

    return @fields;
}
