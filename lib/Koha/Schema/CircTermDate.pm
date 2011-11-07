package Koha::Schema::CircTermDate;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'circ_term_dates',

    columns => [
        id               => { type => 'serial', not_null => 1 },
        circ_termsets_id => { type => 'integer', not_null => 1 },
        startdate        => { type => 'date' },
        enddate          => { type => 'date' },
        duedate          => { type => 'date', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        circ_termsets => {
            class       => 'Koha::Schema::CircTermset',
            key_columns => { circ_termsets_id => 'id' },
        },
    ],
);

1;

