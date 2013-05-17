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

use Koha::Schema::Subscription;
use Koha::Schema::SubscriptionSerial;
use Koha::Schema::SubscriptionSerial::Manager;
use C4::Control::SubscriptionSerial;
use C4::Auth;

sub _create_first_subscriptionserial($$) {
    my ($query, $subscription_id) = @_;

    my $subscription_serial = Koha::Schema::SubscriptionSerial->new;
    $subscription_serial->subscription_id($subscription_id);
    $subscription_serial->periodical_serial_id($query->param('firstserial'));
    $subscription_serial->expected_date($query->param('expected_date') || undef);
    $subscription_serial->status(1);
    $subscription_serial->itemnumber($query->param('itemnumber'));
    $subscription_serial->save;

    return $subscription_serial->id;
}

sub UserCanViewSubscription($;$) {
    my $s = shift;
    my $userid = shift;

    $s = Koha::Schema::Subscription->new(id => $s)->load if not ref $s;
    
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
	next if (not $key);
        my ( $tablename, $fieldname ) = split(/\./, $key );
        $item_defaults->{$fieldname} = $query->param("defaults_$key") if ($query->param("defaults_$key"));
    }
    return $item_defaults;
}

sub HasSerialsAssociated {
    my $subscription_id = shift;

    my $count
        = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials_count(
            query => [ subscription_id => $subscription_id ]
        );
    return ($count != 0) ? 1 : 0;
}

sub UpdateOrCreate($) {
    my $query = shift;
    my $subscription_id = $query->param('subscription_id');

    $subscription_id = try {
        my $subscription = Koha::Schema::Subscription->new;
        if (defined $subscription_id) {
            $subscription->id($subscription_id);
            $subscription->load;
        }
        $subscription->periodical_id($query->param('periodical_id'));
        $subscription->branchcode($query->param('branchcode'));
        $subscription->aqbookseller_id($query->param('aqbookseller_id') || undef);
        $subscription->expiration_date($query->param('expiration_date'));
        $subscription->opac_note($query->param('opac_note'));
        $subscription->staff_note($query->param('staff_note'));
        $subscription->adds_items($query->param('adds_items') || 0);
        $subscription->adds_po_lines($query->param('adds_po_lines') || 0);

	my $item_defaults = ConvertQueryToItemDefaults($query);
	$subscription->item_defaults(to_json($item_defaults));
        $subscription->save;

        if (! defined $query->param('subscription_id')
            || ! HasSerialsAssociated($subscription->id)
            ) {
            _create_first_subscriptionserial($query, $subscription->id);
        }

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

sub Delete($) {
    my $query = shift or croak;
    my $subscription_id = (!ref $query) ? $query : $query->param('subscription_id');
    croak 'Unable to determine subscription_id' if not defined $subscription_id;

    my $retval = try {
        my $s = Koha::Schema::Subscription->new(id => $subscription_id)->load;
        my $parent = $s->periodical_id;
        foreach ($s->subscription_serials) {
            C4::Control::SubscriptionSerial::Delete($_->id);
        }
        $s->delete;
        return $parent;
    }
    catch {
        my $message = "Error deleting subscription: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $retval;
}

sub SetSubscriptionDefaults($$) {
    my ($subscription_id, $item_defaults) = @_;
    croak if (not ($subscription_id and $item_defaults));

    my $subscription = Koha::Schema::Subscription->new(id => $subscription_id)->load();
    $subscription->item_defaults(to_json($item_defaults));
    $subscription->save;
}

sub GetSubscriptionDefaults($) {
    my $subscription_id = shift or croak;

    my $subscription = Koha::Schema::Subscription->new(id => $subscription_id)->load();
    return try {
        from_json($subscription->item_defaults);
    } catch {
        carp sprintf "Malformed item defaults: %s\nThrowing away\n", $_;
        undef;
    };
}

sub GetSummary {
    my $subscription_id = shift || die;

    # From the list of all associated subscription_serials, pick the earliest and
    # latest. Generate a structure like:
    #
    #  [
    #    { first: {
    #        sequence: '1:2:3',
    #        publication_date: '2010-01-01' # a DateTime object, really
    #      },
    #      last: {
    #        sequence: '1:3:3',
    #        publication_date: '2011-01-01'
    #      },
    #    ...
    #  ]
    # This leaves room for a list of summaries if there are substantial breaks
    # in the holdings (though we don't do this as yet).

    my $subscription_serials;
    $subscription_serials
        = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials(
            with_objects => ['periodical_serial'],
            query => [
                subscription_id => $subscription_id,
                't2.sequence' => { like => '%:%' },
            ],
            sort_by => 't2.publication_date ASC',
            limit => 1,
        );
    if (scalar @{$subscription_serials} == 0) {
        return [];
    }
    my $first_serial = shift(@$subscription_serials);

    $subscription_serials
        = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials(
            with_objects => ['periodical_serial'],
            query => [
                subscription_id => $subscription_id,
                't2.sequence' => { like => '%:%' },
            ],
            sort_by => 't2.publication_date DESC',
            limit => 1,
        );
    my $last_serial = shift(@$subscription_serials);

    my $summary_list = [
        {
            first => {
                sequence => $first_serial->periodical_serial->sequence,
                publication_date => $first_serial->periodical_serial->publication_date,
            },
            last => {
                sequence => $last_serial->periodical_serial->sequence,
                publication_date => $last_serial->periodical_serial->publication_date,
            }
        }
    ];
    
    return $summary_list;
}

1;
