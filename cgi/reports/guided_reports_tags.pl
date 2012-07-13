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
use C4::Service;

use CGI;
use JSON;

# return true if the given tag is composed of valid characters
sub is_valid_tag {
    @_;
}

# return true if the script is handling an AJAX request
sub is_xhr {
    no warnings;
    $ENV{HTTP_X_REQUESTED_WITH} eq "XMLHttpRequest";
}

# add a tag to the C4::Report class
sub add {
    my ($cgi) = @_;
    my $tag = $cgi->param('tag');
    my $success = 0;
    my $reason  = "";
    if (C4::Report->has_tag($tag)) {
        $success = 0;
        $reason  = "Tag already exists";
    } else {
        if (is_valid_tag($tag)) {
            C4::Report->add_tag($tag) if ($tag);
            $success = 1;
        } else {
            $success = 0;
            $reason  = "Invalid tag";
        }
    }
    if (is_xhr) {
        print $cgi->header('text/plain');
        print encode_json({ success => $success, reason => $reason });
    } else {
        my $uri = $cgi->param('redirect_to');
        print $cgi->redirect($uri);
    }
}

# remove a tag from the C4::Report class
sub remove {
    my ($cgi) = @_;
    my $tag = $cgi->param('tag');
    C4::Report->remove_tag($tag) if ($tag);
    if (is_xhr) {
        print $cgi->header('text/plain');
        print encode_json({ success => 1 });
    } else {
        my $uri = $cgi->param('redirect_to');
        print $cgi->redirect($uri);
    }
}

# dispatch the request to a handler based on $cgi->param('action');
sub dispatch {
    my %handler = (
        add    => \&add,
        remove => \&remove,
    );
    my ($cgi, $response) = C4::Service->init(reports => 1);
    my $action = $cgi->param('action') || 'x';
    if (not exists $handler{$action}) {
        my $status = 400;
        print $cgi->header(-status => $status);
        print $cgi->div(
            $cgi->h1($status),
            $cgi->p("$action is not supported.")
        );
    } else {
        $handler{$action}->($cgi);
    }
}

# main
dispatch if $ENV{REQUEST_URI};
1;

=head1 NAME

reports/guided_reports_tags.pl - tag manipulation for C4::Report

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
