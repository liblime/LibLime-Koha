package Koha::Schema::Userflag;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'userflags',

    columns => [
        bit       => { type => 'integer', not_null => 1 },
        flag      => { type => 'varchar', length => 30 },
        flagdesc  => { type => 'varchar', length => 255 },
        defaulton => { type => 'integer' },
    ],

    primary_key_columns => [ 'bit' ],

    relationships => [
        permissions => {
            class      => 'Koha::Schema::Permission',
            column_map => { bit => 'module_bit' },
            type       => 'one to many',
        },
    ],
);

1;

