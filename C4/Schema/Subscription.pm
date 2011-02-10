package C4::Schema::Subscription;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

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
        periodical => {
            class       => 'C4::Schema::Periodical',
            key_columns => { periodical_id => 'id' },
        },
    ],

    relationships => [
        subscription_serials => {
            class      => 'C4::Schema::SubscriptionSerial',
            column_map => { id => 'subscription_id' },
            type       => 'one to many',
        },
    ],
);

1;

