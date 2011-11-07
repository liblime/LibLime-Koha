#!/usr/bin/env perl
#
# Copyright 2009 PTFS Inc
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
use C4::Members;

#my $dbh = C4::Context->dbh;
my ( $borrowernotes, $opacnote );

my $query          = new CGI;
my $borrowernumber = $query->param('borrowernumber');
my $screen         = $query->param('screen');

if ( $screen && $screen eq 'update' ) {
    $borrowernotes = $query->param('borrowernotes');
    $opacnote      = $query->param('opacnote');
    my $success = ModMember(
        borrowernumber => $borrowernumber,
        borrowernotes  => $borrowernotes,
        opacnote       => $opacnote
    );
    if ($success) {
        print $query->redirect(
            "/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber"
        );
        exit 0;
    }
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'members/membernote.tmpl',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => '*' },
        debug           => 1,
    }
);

my $data = GetMember( $borrowernumber, 'borrowernumber' );

$template->param($data);

if ( $data->{borrowernotes} ) {
    $borrowernotes = $data->{borrowernotes};
}
else {
    $borrowernotes = q{};
}
if ( $data->{opacnote} ) {
    $opacnote = $data->{opacnote};
}
else {
    $opacnote = q{};
}

$template->param(
    borrowernumber => $borrowernumber,
    borrowernotes  => $borrowernotes,
    opacnote       => $opacnote,
);

if ( $data->{flags} ) {
    $template->param( flags => $data->{flags} );
}

output_html_with_http_headers $query, $cookie, $template->output;
