package Koha::Schema::Z3950server;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'z3950servers',

    columns => [
        host        => { type => 'varchar', length => 255 },
        port        => { type => 'integer' },
        db          => { type => 'varchar', alias => 'db_col', length => 255 },
        userid      => { type => 'varchar', length => 255 },
        password    => { type => 'varchar', length => 255 },
        name        => { type => 'scalar', length => 16777215 },
        id          => { type => 'serial', not_null => 1 },
        checked     => { type => 'integer' },
        rank        => { type => 'integer' },
        syntax      => { type => 'varchar', length => 80 },
        icon        => { type => 'text', length => 65535 },
        position    => { type => 'enum', check_in => [ 'primary', 'secondary', '' ], default => 'primary', not_null => 1 },
        type        => { type => 'enum', check_in => [ 'zed', 'opensearch' ], default => 'zed', not_null => 1 },
        encoding    => { type => 'text', length => 65535 },
        description => { type => 'text', length => 65535, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

