package Koha::Schema::Accounttype;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'accounttypes',

    columns => [
        id          => { type => 'serial', not_null => 1 },
        accounttype => { type => 'varchar', default => '', length => 16, not_null => 1 },
        description => { type => 'scalar', length => 16777215 },
        class       => { type => 'enum', check_in => [ 'fee', 'payment', 'transaction', 'allocation', 'status' ], default => 'fee', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    relationships => [
        fees => {
            class      => 'Koha::Schema::Fee',
            column_map => { accounttype => 'accounttype' },
            type       => 'one to many',
        },

        payments => {
            class      => 'Koha::Schema::Payment',
            column_map => { accounttype => 'accounttype' },
            type       => 'one to many',
        },
    ],
);

1;

