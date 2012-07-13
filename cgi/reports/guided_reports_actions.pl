#!/usr/bin/perl

# Copyright 2009 Liblime ltd
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

use C4::Report;

use CGI;
use JSON;

# toggle a tag for the selected report_ids
sub tag {
    my ($cgi)       = @_;
    my @report_ids  = $cgi->param('report_id');
    my $tag         = $cgi->param('tag');
    my $redirect_to = $cgi->param('redirect_to');
    for (@report_ids) {
        my $report = C4::Report->find($_);
        $report->toggle_tag($tag) if $report;
    }
    print $cgi->redirect($redirect_to);
}

# delete the selected report_ids
sub delete {
    my ($cgi) = @_;
    my @report_ids  = $cgi->param('report_id');
    my $redirect_to = $cgi->param('redirect_to');
    for (@report_ids) {
        C4::Report->delete($_);
    }
    print $cgi->redirect($redirect_to);
}

# dispatch the request to a handler based on $cgi->param('action');
sub dispatch {
    my %handler = (
        tag    => \&tag,
        delete => \&delete,
    );
    my $cgi = CGI->new;
    my $action_raw = $cgi->param('action') || 'x';
    my ($action, $tag);
    if ($action_raw =~ /:/) {
        ($action, $tag) = split(':', $action_raw);
        $cgi->param(tag => $tag);
    } else {
        $action = $action_raw;
    }
    if (not exists $handler{$action}) {
        print $cgi->redirect($cgi->param('redirect_to'));
    } else {
        $handler{$action}->($cgi);
    }
}

# main
dispatch if $ENV{REQUEST_URI};
1;

=head1 NAME

reports/guided_reports_actions.pl - perform actions on C4::Report objects

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
