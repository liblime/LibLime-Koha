package C4::Schema::Periodical;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'periodicals',

    columns => [
        biblionumber      => { type => 'integer', not_null => 1 },
        chronology_format => { type => 'varchar', length => 64 },
        frequency         => { type => 'varchar', length => 16, not_null => 1 },
        id                => { type => 'serial', not_null => 1 },
        iterator          => { type => 'varchar', length => 48, not_null => 1 },
        sequence_format   => { type => 'varchar', length => 64 },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'biblionumber' ],

    foreign_keys => [
        biblio => {
            class       => 'C4::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
            rel_type    => 'one to one',
        },
    ],

    relationships => [
        periodical_serials => {
            class      => 'C4::Schema::PeriodicalSerial',
            column_map => { id => 'periodical_id' },
            type       => 'one to many',
        },

        subscriptions => {
            class      => 'C4::Schema::Subscription',
            column_map => { id => 'periodical_id' },
            type       => 'one to many',
        },
    ],
);

1;

