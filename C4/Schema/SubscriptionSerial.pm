package C4::Schema::SubscriptionSerial;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'subscription_serials',

    columns => [
        expected_date        => { type => 'date' },
        id                   => { type => 'serial', not_null => 1 },
        itemnumber           => { type => 'integer' },
        periodical_serial_id => { type => 'integer', not_null => 1 },
        received_date        => { type => 'datetime' },
        status               => { type => 'integer', default => 1, not_null => 1 },
        subscription_id      => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        item => {
            class       => 'C4::Schema::Item',
            key_columns => { itemnumber => 'itemnumber' },
        },

        periodical_serial => {
            class       => 'C4::Schema::PeriodicalSerial',
            key_columns => { periodical_serial_id => 'id' },
        },

        subscription => {
            class       => 'C4::Schema::Subscription',
            key_columns => { subscription_id => 'id' },
        },
    ],
);

1;

