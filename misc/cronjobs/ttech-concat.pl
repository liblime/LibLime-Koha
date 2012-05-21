#!/usr/bin/env perl

use Koha;
use C4::Letters;
use C4::Circulation qw( GetOpenIssue );

sub pruner {
    my $m = shift;

    # Prune reserve notices that have already been checked out.
    return 1
        if $m->{code} eq 'RESERVE' && GetOpenIssue($m->{itemnumber});

    # Prune overdue notices that have already been returned.
    return 1
        if $m->{code} eq 'OVERDUE' && !GetOpenIssue($m->{itemnumber});

    # Otherwise, send it off.
    return;
}

print C4::Letters::ttech_compose_todo_file( undef, \&pruner );
