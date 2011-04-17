package Koha::Schema::Alert;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'alert',

    columns => [
        alertid        => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer', default => '0', not_null => 1 },
        type           => { type => 'varchar', default => '', length => 10, not_null => 1 },
        externalid     => { type => 'varchar', default => '', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'alertid' ],
);

1;

