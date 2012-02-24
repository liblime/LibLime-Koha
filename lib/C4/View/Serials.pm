package C4::View::Serials;

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
    SeedTemplateWithGeneralData
    SeedTemplateWithPeriodicalData
    SeedTemplateWithPeriodicalSerialData
    SeedTemplateWithSubscriptionSerialData
    SeedTemplateWithSubscriptionData
    SeedTemplateWithSubscriptionDefaults
    SeedTemplateWithSubscriptionItemFields
    GetSubscriptionItemFields
    );

use Carp;
use CGI;
use Rose::DB::Object::Helpers qw(column_value_pairs);
use Try::Tiny;

use Koha::Schema::Periodical;
use Koha::Schema::Periodical::Manager;
use Koha::Schema::PeriodicalSerial;
use Koha::Schema::PeriodicalSerial::Manager;
use Koha::Schema::Subscription;
use Koha::Schema::Subscription::Manager;
use Koha::Schema::SubscriptionSerial;
use Koha::Schema::SubscriptionSerial::Manager;
use C4::Model::Periodical::Chronology;
use C4::Control::PeriodicalSerial;
use C4::Control::Periodical;
use C4::Control::Subscription;
use C4::Koha;
use C4::Biblio;
use C4::Branch;
use C4::Auth;
use C4::View::SerialsFormats
    qw(@frequency_formats @sequence_formats @chronology_formats);

our @statuses = (
    {id => 0, human => 'Future'},
    {id => 1, human => 'Expected'},
    {id => 2, human => 'Arrived'},
    {id => 3, human => 'Late'},
    {id => 4, human => 'Not Available'},
    {id => 7, human => 'Claimed'},
    );

sub SeedTemplateWithGeneralData($) {
    my $template = shift or croak;

    my @branchloop = map {@{GetBranchInfo($_)}} GetUserGroupBranches('subscriptions');

    $template->param(
        DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
        branchloop => \@branchloop,
        frequency_formats => \@frequency_formats,
        sequence_formats => \@sequence_formats,
        chronology_formats => \@chronology_formats,
        statuses => \@statuses,
    );
    return $template;
}

sub _set_datetime_format {
    my ($array, $field) = @_;

    if(defined $array) {
        $_->{$field} && $_->{$field}->set_formatter(C4::Model::Periodical::Chronology->new(pattern => C4::Dates->DHTMLcalendar)) for (@{$array});
    } elsif ($field) {
        croak unless $field->isa('DateTime');
        $field->set_formatter(C4::Model::Periodical::Chronology->new(pattern => C4::Dates->DHTMLcalendar));
    }
}

sub _get_periodical_subscriptions_details($) {
    my $p = shift or croak;

    my @branches = C4::Auth::GetUserGroupBranches('subscriptions');

    my @subs = map {scalar column_value_pairs($_)} @{Koha::Schema::Subscription::Manager->get_subscriptions(
        query => [ periodical_id => $p->id, branchcode => \@branches ], sort_by => 'branchcode')};
    _set_datetime_format(\@subs, 'expiration_date');
    return \@subs;
}

sub SeedTemplateWithPeriodicalData($$) {
    my ($template, $periodical_id) = @_;
    try {
        my $periodical = Koha::Schema::Periodical->new(id => $periodical_id)->load;
        my (undef, @biblios) = GetBiblio($periodical->biblionumber);
        $template->param(
            biblionumber => $periodical->biblionumber,
            frequency => $periodical->frequency,
            frequency_expressed => $C4::View::SerialsFormats::frequency_map{$periodical->frequency},
            sequence_format => $periodical->sequence_format,
            sequence_expressed => C4::Control::PeriodicalSerialFormats::FormatSequence(
                $periodical->sequence_format, '14:2:5', '2010'),
            chronology_format => $periodical->chronology_format,
            iterator => $periodical->iterator,
            bibliotitle => $biblios[0]->{title},
            periodical_id => $periodical_id,
        );

        if($periodical->chronology_format ne '') {
            $template->param(
                chronology_expressed => C4::Control::PeriodicalSerialFormats::FormatChronology(
                    $periodical->chronology_format, DateTime->now),
            );
        }
        my @periodical_serials = map {scalar column_value_pairs($_)} @{Koha::Schema::PeriodicalSerial::Manager->get_periodical_serials(
            query => [ periodical_id => $periodical_id ], sort_by => 'publication_date')};
        _set_datetime_format(\@periodical_serials, $_) for qw(publication_date);
        foreach (@periodical_serials) {
            $_->{expected} = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials_count(
                query => [periodical_serial_id => $_->{id}, status => 1]);
            $_->{arrived} = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials_count(
                query => [periodical_serial_id => $_->{id}, status => 2]);
        }

        $template->param(periodical_serials_loop => \@periodical_serials);
        $template->param(subscriptions_loop => _get_periodical_subscriptions_details($periodical));
        $template->param(subscription_count =>
                         Koha::Schema::Subscription::Manager->get_subscriptions_count(
                             query => [periodical_id => $periodical_id]
                         ));
        $template;
    } catch {
        my $message = sprintf "Error seeding data for periodical #%d: $_", $periodical_id // -1;
        carp $message;
        $template->param(error => $message);
        undef;
    };
}

sub SeedTemplateWithPeriodicalSerialData($$) {
    my ($template, $periodical_serial_id) = @_;
    try {
        my $ps_flat = column_value_pairs(Koha::Schema::PeriodicalSerial->new(id => $periodical_serial_id)->load);
        _set_datetime_format(undef, $ps_flat->{publication_date});
        $template->param(periodical_serials_loop => [$ps_flat]);
        $template->param(periodical_id => $ps_flat->{periodical_id});
        $template->param(subscription_serial_count =>
                         Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials_count(
                             query => [periodical_serial_id => $periodical_serial_id]
                         ));
        $template;
    } catch {
        my $message = sprintf "Error seeding data for periodical_serial #%d: $_", $periodical_serial_id // -1;
        carp $message;
        $template->param(error => $message);
        undef;
    }
}

sub SeedTemplateWithSubscriptionSerialData($$) {
    my ($template, $subscription_serial_id) = @_;
    try {
        my $ss = Koha::Schema::SubscriptionSerial->new(id => $subscription_serial_id)->load;
        my $ss_flat = column_value_pairs($ss);
        $ss_flat->{sequence} = $ss->periodical_serial->sequence;
        $ss_flat->{vintage} = $ss->periodical_serial->vintage;
        $ss_flat->{publication_date} = $ss->periodical_serial->publication_date;
        _set_datetime_format(undef, $ss_flat->{$_}) for qw(received_date publication_date expected_date);
        $template->param(subscription_serials_loop => [$ss_flat]);
        SeedTemplateWithPeriodicalData($template, $ss->subscription->periodical_id);
        $template;
    } catch {
        my $message = sprintf "Error seeding data for subscription_serial #%d: $_", $subscription_serial_id // -1;
        carp $message;
        $template->param(error => $message);
        undef;
    }
}

sub SeedTemplateWithSubscriptionDefaults($;$) {
    my $template = shift or die;
    my $s_id = shift;
    $template->param(defaults_loop => GetSubscriptionItemFields($s_id));
    return $template;
}

sub SeedTemplateWithSubscriptionData($$) {
    my ($template, $subscription_id) = @_;
    my $subscription = Koha::Schema::Subscription->new(id => $subscription_id)->load;

    try {
        $template->param(
            subscription_id => $subscription->id,
            branchcode => $subscription->branchcode,
            branchname => GetBranchName($subscription->branchcode),
            aqbookseller_id => $subscription->aqbookseller_id,
            expiration_date => _set_datetime_format(undef, $subscription->expiration_date),
            adds_items => $subscription->adds_items,
            opac_note => $subscription->opac_note,
            staff_note => $subscription->staff_note,
            );

        SeedTemplateWithSubscriptionDefaults($template, $subscription_id);
        my $ss_list = Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials(query => [ subscription_id => $subscription_id ]);
        my @ss_flats;
        foreach my $ss (@$ss_list) {
            my $ss_flat = {
                id => $ss->id,
                sequence => $ss->periodical_serial->sequence,
                vintage => $ss->periodical_serial->vintage,
                publication_date => _set_datetime_format(undef, $ss->periodical_serial->publication_date),
                received_date => $ss->received_date,
                expected_date => $ss->expected_date,
                status => $statuses[$ss->status]->{human},
                };
            _set_datetime_format(undef, $ss_flat->{$_}) for qw(received_date expected_date);
            push @ss_flats, $ss_flat;
        }
        $template->param(subscription_serials_loop => \@ss_flats);
        $template->param(subscription_serial_count =>
                         Koha::Schema::SubscriptionSerial::Manager->get_subscription_serials_count(
                             query => [subscription_id => $subscription_id]
                         ));
        if (!C4::Control::Subscription::HasSerialsAssociated($subscription_id)) {
            $template->param(needs_firstserial => 1);
        }
        $template;
    } catch {
        my $message = sprintf "Error seeding data for subscription #%d: $_", $subscription_id // -1;
        carp $message;
        $template->param(error => $message);
        undef;
    };
}

sub SeedTemplateWithPeriodicalSearch($$$) {
    my ($template, $key, $value) = @_;
    my $periodicals = C4::Control::Periodical::SearchPeriodicals($key => $value);

    my @periodicals = map {scalar column_value_pairs($_)} @{$periodicals};
    foreach my $p (@periodicals) {
        my (undef, @biblios) = GetBiblio($p->{biblionumber});
        $p->{bibliotitle} = $biblios[0]->{title};
        $p->{subscription_count} = Koha::Schema::Subscription::Manager->get_subscriptions_count(query => [periodical_id => $p->{id}]);
    }
    $template->param('searchresults_loop' => \@periodicals);
    $template;
};

sub GetSubscriptionItemFields($) {
    my $subscription_id = shift;
    my @subfields
        = C4::Koha::GetMarcSubfieldStructure( 'items', 'SER',
                                              ['items.itemnumber',
                                               'items.biblionumber',
                                               'items.biblioitemnumber',
                                               'items.barcode',
                                               'items.callnumber',
                                               'items.homebranch',
                                               'items.holdingbranch'
                                              ] );
    # It doesn't make sense to set defaults for some of these subfields. Remove them.
    @subfields = grep {$_->{tagsubfield} !~ /[012456dhjklmnqrs]/} @subfields;

    my $defaults = ($subscription_id)
        ? C4::Control::Subscription::GetSubscriptionDefaults($subscription_id)
        : {};

    foreach my $s ( @subfields ) {
	my ( $table, $column ) = split( /\./, $s->{kohafield} );
	$s->{value} = $defaults->{ $column } // $s->{defaultvalue};
        if ($s->{authorised_value}) {
            $s->{authorised_values}
                = GetAuthorisedValues($s->{authorised_value}, $defaults->{$column});
        }
	if ( $column eq 'itype' ) {
	    my @itemtypes = C4::ItemType->all;
	    my @authorised_values;
	    foreach my $i ( @itemtypes ) {
		my $v;
		$v->{authorised_value} = $i->{itemtype};
		$v->{lib} = $i->{description};
		$v->{selected} = 1 if ( $defaults->{$column} and $i->{itemtype} eq $defaults->{$column} );
		push( @authorised_values, $v );
	    }
	    $s->{authorised_values} = \@authorised_values;
	}  
        for my $authval ( @{$s->{authorised_values}} ) {
            if ($s->{value} ~~ $authval->{authorised_value}) {
                $authval->{selected} = 1;
                next;
            }
        }
    }
    return \@subfields;
}

1;
