package Koha::Schema::PeriodicalSerial;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'periodical_serials',

    columns => [
        id               => { type => 'serial', not_null => 1 },
        periodical_id    => { type => 'integer', not_null => 1 },
        sequence         => { type => 'varchar', length => 16 },
        vintage          => { type => 'varchar', length => 64, not_null => 1 },
        publication_date => { type => 'date', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        periodical => {
            class       => 'Koha::Schema::Periodical',
            key_columns => { periodical_id => 'id' },
        },
    ],

    relationships => [
        items => {
            map_class => 'Koha::Schema::SubscriptionSerial',
            map_from  => 'periodical_serial',
            map_to    => 'item',
            type      => 'many to many',
        },

        subscription_serials => {
            class      => 'Koha::Schema::SubscriptionSerial',
            column_map => { id => 'periodical_serial_id' },
            type       => 'one to many',
        },
    ],
);

1;

