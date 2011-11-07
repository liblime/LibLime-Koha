package Koha::Schema::CircTermset;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'circ_termsets',

    columns => [
        id          => { type => 'serial', not_null => 1 },
        description => { type => 'varchar', length => 64 },
        branchcode  => { type => 'varchar', length => 10 },
    ],

    primary_key_columns => [ 'id' ],

    relationships => [
        circ_term_dates => {
            class      => 'Koha::Schema::CircTermDate',
            column_map => { id => 'circ_termsets_id' },
            type       => 'one to many',
        },
    ],
);

1;

