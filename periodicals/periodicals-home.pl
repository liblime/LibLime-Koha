#!/usr/bin/env perl

# Copyright 2010 PTFS, Inc.
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
use C4::Output;
use C4::View::Serials;

my $query = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "periodicals/periodicals-home.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 1,
        flagsrequired   => { serials => '*' },
        debug           => 1,
    }
);

if ($query->param('issn_filter')) {
    C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, issn => $query->param('issn_filter'));
} elsif ($query->param('title_filter')) {
    C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, title => $query->param('title_filter'));
}

output_html_with_http_headers $query, $cookie, $template->output;
