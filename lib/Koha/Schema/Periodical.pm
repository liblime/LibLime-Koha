package Koha::Schema::Periodical;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'periodicals',

    columns => [
        id                => { type => 'serial', not_null => 1 },
        biblionumber      => { type => 'integer', not_null => 1 },
        iterator          => { type => 'varchar', length => 48, not_null => 1 },
        frequency         => { type => 'varchar', length => 16, not_null => 1 },
        sequence_format   => { type => 'varchar', length => 64 },
        chronology_format => { type => 'varchar', length => 64 },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'biblionumber' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
            rel_type    => 'one to one',
        },
    ],

    relationships => [
        periodical_serials => {
            class      => 'Koha::Schema::PeriodicalSerial',
            column_map => { id => 'periodical_id' },
            type       => 'one to many',
        },

        subscriptions => {
            class      => 'Koha::Schema::Subscription',
            column_map => { id => 'periodical_id' },
            type       => 'one to many',
        },
    ],
);

1;

