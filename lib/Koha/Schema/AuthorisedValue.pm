package Koha::Schema::AuthorisedValue;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'authorised_values',

    columns => [
        id               => { type => 'serial', not_null => 1 },
        category         => { type => 'varchar', default => '', length => 10, not_null => 1 },
        authorised_value => { type => 'varchar', default => '', length => 80, not_null => 1 },
        prefix           => { type => 'varchar', length => 80 },
        lib              => { type => 'varchar', length => 80 },
        imageurl         => { type => 'varchar', length => 200 },
        opaclib          => { type => 'varchar', length => 80 },
    ],

    primary_key_columns => [ 'id' ],

    relationships => [
        summaries => {
            class      => 'Koha::Schema::Summary',
            column_map => { id => 'collection_code' },
            type       => 'one to many',
        },

        summaries_objs => {
            class      => 'Koha::Schema::Summary',
            column_map => { id => 'shelvinglocation' },
            type       => 'one to many',
        },
    ],
);

1;

