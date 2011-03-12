#!/usr/bin/env perl
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
use C4::View::Serials qw(
    SeedTemplateWithPeriodicalData
    SeedTemplateWithGeneralData
    );
use C4::Control::Periodical;

my $query = new CGI;
my $op = $query->param('op') || '';
my $periodical_id = $query->param('periodical_id');
my ($template, $loggedinuser, $cookie) = 
  get_template_and_user({template_name => "periodicals/periodicals-add.tmpl",
                query => $query,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => '*'},
                debug => 1,
                });

if ($op eq 'save' && (
        (C4::Auth::haspermission(C4::Context->userenv->{id}, {serials => 'periodical_edit'}) && defined $periodical_id)
        || (C4::Auth::haspermission(C4::Context->userenv->{id}, {serials => 'periodical_create'}) && ! defined $periodical_id)
    )) {
    $periodical_id = C4::Control::Periodical::UpdateOrCreate($query);
}

SeedTemplateWithPeriodicalData($template, $periodical_id) if $periodical_id;
SeedTemplateWithGeneralData($template);
output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
