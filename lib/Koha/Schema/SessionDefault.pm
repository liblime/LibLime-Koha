package Koha::Schema::SessionDefault;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'session_defaults',

    columns => [
        branchcode => { type => 'varchar', length => 10, not_null => 1 },
        name       => { type => 'varchar', length => 32, not_null => 1 },
        key        => { type => 'varchar', length => 32, not_null => 1 },
        value      => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'branchcode', 'name' ],
);

1;

