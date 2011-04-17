package Koha::Schema::DefaultCircRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'default_circ_rules',

    columns => [
        singleton   => { type => 'enum', check_in => [ 'singleton' ], not_null => 1 },
        maxissueqty => { type => 'integer' },
        holdallowed => { type => 'integer' },
    ],

    primary_key_columns => [ 'singleton' ],
);

1;

