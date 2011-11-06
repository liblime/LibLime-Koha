package Koha::Schema::Subscription;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'subscriptions',

    columns => [
        id              => { type => 'serial', not_null => 1 },
        periodical_id   => { type => 'integer', not_null => 1 },
        branchcode      => { type => 'varchar', length => 10 },
        aqbookseller_id => { type => 'integer' },
        expiration_date => { type => 'date' },
        opac_note       => { type => 'text', length => 65535 },
        staff_note      => { type => 'text', length => 65535 },
        item_defaults   => { type => 'text', length => 65535, not_null => 1 },
        adds_items      => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        aqbookseller => {
            class       => 'Koha::Schema::Aqbookseller',
            key_columns => { aqbookseller_id => 'id' },
        },

        periodical => {
            class       => 'Koha::Schema::Periodical',
            key_columns => { periodical_id => 'id' },
        },
    ],

    relationships => [
        subscription_serials => {
            class      => 'Koha::Schema::SubscriptionSerial',
            column_map => { id => 'subscription_id' },
            type       => 'one to many',
        },
    ],
);

1;

