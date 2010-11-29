package C4::Model::SubscriptionSerial;

use strict;

use base qw(C4::Model::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'subscription_serials',

    columns => [
        id                   => { type => 'serial', not_null => 1 },
        subscription_id      => { type => 'integer', not_null => 1 },
        periodical_serial_id => { type => 'integer', not_null => 1 },
        status               => { type => 'integer', default => 1, not_null => 1 },
        expected_date        => { type => 'date' },
        received_date        => { type => 'datetime' },
        itemnumber           => { type => 'integer' },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        item => {
            class       => 'C4::Model::Item',
            key_columns => { itemnumber => 'itemnumber' },
        },

        periodical_serial => {
            class       => 'C4::Model::PeriodicalSerial',
            key_columns => { periodical_serial_id => 'id' },
        },

        subscription => {
            class       => 'C4::Model::Subscription',
            key_columns => { subscription_id => 'id' },
        },
    ],
);

1;

