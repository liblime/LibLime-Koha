package Koha::Schema::SubscriptionSerial;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'subscription_serials',

    columns => [
        id                   => { type => 'serial', not_null => 1 },
        subscription_id      => { type => 'integer', not_null => 1 },
        periodical_serial_id => { type => 'integer', not_null => 1 },
        status               => { type => 'integer', default => 1, not_null => 1 },
        received_date        => { type => 'datetime' },
        itemnumber           => { type => 'integer' },
        expected_date        => { type => 'date' },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        item => {
            class       => 'Koha::Schema::Item',
            key_columns => { itemnumber => 'itemnumber' },
        },

        periodical_serial => {
            class       => 'Koha::Schema::PeriodicalSerial',
            key_columns => { periodical_serial_id => 'id' },
        },

        subscription => {
            class       => 'Koha::Schema::Subscription',
            key_columns => { subscription_id => 'id' },
        },
    ],
);

1;

