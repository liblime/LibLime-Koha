#!/usr/bin/perl

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
use C4::Debug;
use C4::View::Serials qw(
    SeedTemplateWithSubscriptionSerialData
    SeedTemplateWithGeneralData
    );
use C4::Control::Periodical;
use C4::Control::SubscriptionSerial;

my $query = new CGI;
my $op = $query->param('op') || '';
my $subscription_serial_id = $query->param('subscription_serial_id');
my ($template, $loggedinuser, $cookie) = 
  get_template_and_user({template_name => "periodicals/subscription_serial-edit.tmpl",
                query => $query,
                type => "intranet",
                authnotrequired => 0,
                flagsrequired => {serials => 1},
                debug => 1,
                });

my $subscription_serial = C4::Schema::SubscriptionSerial->new(id => $subscription_serial_id)->load;
if ($subscription_serial and C4::Control::Subscription::UserCanViewSubscription($subscription_serial->subscription_id)) {
    if ($op eq 'save') {
        $subscription_serial_id = C4::Control::SubscriptionSerial::Update($query);
        my $periodical_id
            = C4::Schema::SubscriptionSerial->new(id => $subscription_serial_id)->load->subscription->periodical_id;
        C4::Control::Periodical::UpdateBiblioSummary($periodical_id);
        print $query->redirect("subscription-detail.pl?subscription_id=".$subscription_serial->subscription_id);
    }
    SeedTemplateWithSubscriptionSerialData($template, $subscription_serial_id) if $subscription_serial_id;
    SeedTemplateWithGeneralData($template);
}

output_html_with_http_headers $query, $cookie, $template->output;

exit 0;
