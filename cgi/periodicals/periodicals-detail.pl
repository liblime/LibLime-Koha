#!/usr/bin/env perl

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
use C4::Biblio;
use C4::Debug;
use C4::Control::PeriodicalSerial;
use C4::View::Serials qw(
    SeedTemplateWithPeriodicalData
    );

my $query = new CGI;
my $periodical_id = $query->param('periodical_id');
my ($template, $loggedinuser, $cookie) = 
  get_template_and_user({template_name => "periodicals/periodicals-detail.tmpl",
                query => $query,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => '*'},
                debug => 1,
                });

C4::Control::PeriodicalSerial::GenerateNextInSeries($periodical_id) if
    ($query->param('op') and $query->param('op') eq 'gen_next_seq');

SeedTemplateWithPeriodicalData($template, $periodical_id);

my @branches = C4::Auth::GetUserGroupBranches('subscriptions');
@{$template->param('subscriptions_loop')} = grep { $$_{branchcode} ~~ @branches } @{$template->param('subscriptions_loop')};

output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
