#!/usr/bin/env perl
#
# Copyright 2011 LibLime/PTFS, Inc.
# http://www.ptfs.com
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

use Koha;
use CGI;
use C4::Output;
use C4::Auth;
use C4::Biblio;
use C4::Dates;

my $cgi = CGI->new();
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "reserve/editholds.tmpl",
        query           => $cgi,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reserveforothers => '*' },
    }
);

my $biblionumber   = $cgi->param('biblionumber');
my $bib            = C4::Biblio::GetBiblioData($biblionumber);
my $limit          = $cgi->param('limit')    || 10;
my $offset         = $cgi->param('offset')   || 0;
my $mode           = $cgi->param('mode')     || 'batch'; # else: single
my $dformat        = C4::Context->preference('dateformat') // 'iso';
my $pg             = $cgi->param('pg')       || 1;
my $sortf          = $cgi->param('sortf')    || 'int:priority';
my $sortRev        = $cgi->param('sortRev')  || 'DESC';
$template->param(
   editholdsview => 1,
   pg            => $pg,
   sortf         => $sortf,
   sortRev       => $sortRev,
   HTTP_HOST     => $ENV{HTTP_HOST},
   dateformat    => $dformat,
   biblionumber  => $biblionumber,
   title         => $$bib{title},
   offset        => $offset,
   limit         => $limit,
   mode          => $mode,
   DHTMLcalendar_dateformat  => C4::Dates->DHTMLcalendar($dformat),
   SessionStorage => C4::Context->preference('SessionStorage'),
);
    
output_html_with_http_headers $cgi, $cookie, $template->output;
exit;
__END__
