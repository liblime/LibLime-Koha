package Koha::Schema::Systempreference;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'systempreferences',

    columns => [
        variable    => { type => 'varchar', length => 50, not_null => 1 },
        value       => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'variable' ],
);

1;

