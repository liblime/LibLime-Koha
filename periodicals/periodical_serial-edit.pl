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
use C4::Output;
use C4::Debug;
use C4::View::Serials qw(
    SeedTemplateWithPeriodicalSerialData
    SeedTemplateWithGeneralData
    );
use C4::Control::Periodical;
use C4::Control::PeriodicalSerial;

my $query = new CGI;
my $op = $query->param('op') || '';
my $periodical_serial_id = $query->param('periodical_serial_id');
my ($template, $loggedinuser, $cookie) = 
  get_template_and_user({template_name => "periodicals/periodical_serial-edit.tmpl",
                query => $query,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => 1},
                debug => 1,
                });

if ($op eq 'save') {
    if ($query->param('count')) {
        $periodical_serial_id
            = C4::Control::PeriodicalSerial::CombineSequences(
                $periodical_serial_id,
                $query->param('count')+1,
                {permanent => ($query->param('permanent') eq 'on')}
            );
    } else {
        $periodical_serial_id = C4::Control::PeriodicalSerial::Update($query);
    }
    C4::Control::Periodical::UpdateBiblioSummary(Koha::Schema::PeriodicalSerial->new(id => $periodical_serial_id)->load->periodical_id);
    print $query->redirect("periodicals-detail.pl?periodical_id=".$query->param('periodical_id'));
}

if (($query->param('op') // '') eq 'combine') {
    $template->param(op => 'combine');
}

SeedTemplateWithPeriodicalSerialData($template, $periodical_serial_id) if $periodical_serial_id;
SeedTemplateWithGeneralData($template);

output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
