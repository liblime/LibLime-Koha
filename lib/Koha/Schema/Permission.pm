package Koha::Schema::Permission;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'permissions',

    columns => [
        module_bit  => { type => 'integer', not_null => 1 },
        code        => { type => 'varchar', length => 64, not_null => 1 },
        description => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'module_bit', 'code' ],

    foreign_keys => [
        module => {
            class       => 'Koha::Schema::Userflag',
            key_columns => { module_bit => 'bit' },
        },
    ],
);

1;

