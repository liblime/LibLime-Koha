package Koha::Schema::Xtag;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'xtags',

    columns => [
        id   => { type => 'serial', not_null => 1 },
        name => { type => 'varchar', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

