package C4::Control::SubscriptionSerial;

use strict;
use warnings;

use Carp;
use Try::Tiny;
use DateTime;
use JSON;

use Koha::App::GetIt;
use Koha::Schema::SubscriptionSerial;
use Koha::Schema::SubscriptionSerial::Manager;
use Koha::Schema::PeriodicalSerial;
use Koha::Schema::PeriodicalSerial::Manager;
use C4::Control::PeriodicalSerial;
use C4::Items qw();

sub _GenerateNextSubscriptionSerial($) {
    my $ss = shift or croak;
    $ss->isa('Koha::Schema::SubscriptionSerial');

    my $ss_list = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials(
	with_objects => ['periodical_serial'],
	query => [ subscription_id => $ss->subscription_id ],
	sort_by => 't2.publication_date DESC',
	limit => 1,
	);
    return if $ss_list->[0]->id != $ss->id;

    my $ps_list = Koha::Schema::PeriodicalSerial::Manager->get_periodical_serials(
	query => [
	    periodical_id => $ss_list->[0]->subscription->periodical_id,
	    publication_date => { gt => $ss_list->[0]->periodical_serial->publication_date },
	],
	sort_by => 'publication_date ASC',
	);

    if (scalar @{$ps_list} == 0) {
	$ps_list->[0] =
	    C4::Control::PeriodicalSerial::GenerateNextInSeries($ss->subscription->periodical);
    }

    my $new_ss = Koha::Schema::SubscriptionSerial->new();
    $new_ss->subscription_id($ss->subscription_id);
    $new_ss->periodical_serial_id($ps_list->[0]->id);
    $new_ss->status(1);
    try {
        $new_ss->expected_date(
            C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed(
                $ss_list->[0]->subscription->periodical->frequency,
                $ss_list->[0]->expected_date
            ));
    };

    $new_ss->save;

    return $new_ss;
}

sub Update($) {
    my $query = shift or croak;
    my $subscription_serial_id = $query->param('subscription_serial_id') // croak;

    $subscription_serial_id = try {
        my $subscription_serial
            = Koha::Schema::SubscriptionSerial->new(id => $subscription_serial_id)->load;;
        my $old_status = $subscription_serial->status;
        my $new_status = $query->param('status');

	$subscription_serial->expected_date($query->param('expected_date') || undef);
        $subscription_serial->received_date($query->param('received_date') || undef);
	$subscription_serial->status($new_status);
        $subscription_serial->save;

        if ($subscription_serial->subscription->adds_po_lines && ($new_status == 2) && ($old_status != 2)) {
            my $getit = new Koha::App::GetIt;
            if ($getit->enabled) {
                $getit->post('purchase_order_lines', {
                        subscriptionid => $subscription_serial->subscription->id,
                        serialid => $subscription_serial->id,
                        title => $subscription_serial->subscription->periodical->biblio->title,
                        issue => $subscription_serial->periodical_serial->vintage,
                        received => 1,
                    }, {
                        view => 'serial'
                    });
            }
        }

	if ($subscription_serial->status > 1) {
	    _GenerateNextSubscriptionSerial($subscription_serial);
	}
        if ($subscription_serial->status == 2
            && $subscription_serial->subscription->adds_items
            && !$subscription_serial->itemnumber) {
            my $item = from_json($subscription_serial->subscription->item_defaults);
            $item->{dateaccessioned} = $subscription_serial->received_date->ymd;
            $item->{enumchron} = $subscription_serial->periodical_serial->vintage;
            $item->{homebranch} = $subscription_serial->subscription->branchcode;
            $item->{holdingbranch} = $subscription_serial->subscription->branchcode;
            my (undef, undef, $itemnumber) = C4::Items::AddItem($item,
                $subscription_serial->subscription->periodical->biblionumber
                );
            croak sprintf "Unable to create item for subscription_serial '%d'\n" if (not defined $itemnumber);
            $subscription_serial->itemnumber($itemnumber);
            $subscription_serial->save;
        }

        $subscription_serial->id;
    } catch {
        my $message = "Error creating or updating subscription serial: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $subscription_serial_id;
}

sub Delete($) {
    my $query = shift or croak;
    my $subscription_serial_id = (!ref $query) ? $query : $query->param('subscription_serial_id');
    croak 'Unable to determine subscription_serial_id' if not defined $subscription_serial_id;

    my $retval = try {
        # FIXME: first delete any associated items, but C4::Items::DelItem is
        # currently too broken
        my $ss = Koha::Schema::SubscriptionSerial->new(id => $subscription_serial_id)->load;
        my $parent = $ss->subscription_id;
        $ss->delete;
        return $parent;
    }
    catch {
        my $message = "Error deleting subscription serial: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $retval;
}

1;
