package Koha::Schema::Aqbasket;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'aqbasket',

    columns => [
        basketno                => { type => 'serial', not_null => 1 },
        creationdate            => { type => 'date' },
        closedate               => { type => 'date' },
        booksellerid            => { type => 'integer', default => 1, not_null => 1 },
        authorisedby            => { type => 'varchar', length => 10 },
        booksellerinvoicenumber => { type => 'scalar', length => 16777215 },
    ],

    primary_key_columns => [ 'basketno' ],

    foreign_keys => [
        aqbookseller => {
            class       => 'Koha::Schema::Aqbookseller',
            key_columns => { booksellerid => 'id' },
        },
    ],

    relationships => [
        aqorders => {
            class      => 'Koha::Schema::Aqorder',
            column_map => { basketno => 'basketno' },
            type       => 'one to many',
        },
    ],
);

1;

