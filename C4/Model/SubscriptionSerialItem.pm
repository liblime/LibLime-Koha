package C4::Model::SubscriptionSerialItem;

use strict;

use base qw(C4::Model::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'subscription_serial_items',

    columns => [
        id                   => { type => 'serial', not_null => 1 },
        periodical_serial_id => { type => 'integer', not_null => 1 },
        itemnumber           => { type => 'integer', not_null => 1 },
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
    ],
);

1;

