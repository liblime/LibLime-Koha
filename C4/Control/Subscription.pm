package C4::Control::Subscription;

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

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    UserCanViewSubscription
    UpdateOrCreate
    );

use Carp;
use Try::Tiny;
use CGI;
use JSON;
use Rose::DB::Object::Helpers qw(column_value_pairs);
use DateTime::Format::Strptime;

use C4::Model::Subscription;
use C4::Model::SubscriptionSerial;
use C4::Auth;

sub _create_first_subscriptionserial($$) {
    my ($query, $subscription_id) = @_;

    my $subscription_serial = C4::Model::SubscriptionSerial->new;
    $subscription_serial->subscription_id($subscription_id);
    $subscription_serial->periodical_serial_id($query->param('firstserial'));
    $subscription_serial->expected_date($query->param('expected_date'));
    $subscription_serial->status(1);
    $subscription_serial->itemnumber($query->param('itemnumber'));
    $subscription_serial->save;

    return $subscription_serial->id;
}

sub UserCanViewSubscription($;$) {
    my $s = shift;
    my $userid = shift;

    $s = C4::Model::Subscription->new(id => $s)->load if not ref $s;
    
    my %branches;
    @branches{GetUserGroupBranches('subscriptions', $userid)} = ();
    return exists $branches{$s->branchcode};
}

sub ConvertQueryToItemDefaults($) {
    my $query = shift or croak;

    my @subfields = C4::Koha::GetMarcSubfieldStructure( 'items', '', ['items.itemnumber', 'items.biblionumber',  'items.barcode', 'items.callnumber'] );
    my $item_defaults = {};
    for my $s (@subfields) {
        my $key = $s->{kohafield};
        my ( $tablename, $fieldname ) = split(/\./, $key );
        $item_defaults->{$fieldname} = $query->param("defaults_$key") if ($query->param("defaults_$key") ne '');
    }
    return $item_defaults;
}

sub UpdateOrCreate($) {
    my $query = shift;
    my $subscription_id = $query->param('subscription_id');

    $subscription_id = try {
        my $subscription = C4::Model::Subscription->new;
        if (defined $subscription_id) {
            $subscription->id($subscription_id);
            $subscription->load;
        }
        $subscription->periodical_id($query->param('periodical_id'));
        $subscription->branchcode($query->param('branchcode'));
        $subscription->aqbookseller_id($query->param('aqbookseller_id') || undef);
        $subscription->expiration_date($query->param('expiration_date'));
        $subscription->adds_items($query->param('adds_items') || 0);

	my $item_defaults = ConvertQueryToItemDefaults($query);
	$subscription->item_defaults(to_json($item_defaults));
        $subscription->save;

        _create_first_subscriptionserial($query, $subscription->id) if (not defined $query->param('subscription_id'));

        print $query->redirect("/cgi-bin/koha/periodicals/subscription-detail.pl?subscription_id=".$subscription->id);
        $subscription->id;
    } catch {
        my $message = "Error creating or updating subscription: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $subscription_id;
}

sub SetSubscriptionDefaults($$) {
    my ($subscription_id, $item_defaults) = @_;
    croak if (not ($subscription_id and $item_defaults));

    my $subscription = C4::Model::Subscription->new(id => $subscription_id)->load();
    $subscription->item_defaults(to_json($item_defaults));
    $subscription->save;
}

sub GetSubscriptionDefaults($) {
    my $subscription_id = shift or croak;

    my $subscription = C4::Model::Subscription->new(id => $subscription_id)->load();
    return try {
        from_json($subscription->item_defaults);
    } catch {
        carp sprintf "Malformed item defaults: %s\nThrowing away\n", $_;
        undef;
    };
}

1;
