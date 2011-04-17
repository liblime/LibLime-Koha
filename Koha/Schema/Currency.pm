package Koha::Schema::Currency;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'currency',

    columns => [
        currency  => { type => 'varchar', length => 10, not_null => 1 },
        symbol    => { type => 'varchar', length => 5 },
        timestamp => { type => 'timestamp', not_null => 1 },
        rate      => { type => 'float', precision => 32 },
    ],

    primary_key_columns => [ 'currency' ],

    relationships => [
        aqbooksellers => {
            class      => 'Koha::Schema::Aqbookseller',
            column_map => { currency => 'listprice' },
            type       => 'one to many',
        },

        aqbooksellers_objs => {
            class      => 'Koha::Schema::Aqbookseller',
            column_map => { currency => 'invoiceprice' },
            type       => 'one to many',
        },
    ],
);

1;

