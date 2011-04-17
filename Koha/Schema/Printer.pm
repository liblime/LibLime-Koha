package Koha::Schema::Printer;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'printers',

    columns => [
        printername => { type => 'varchar', length => 40, not_null => 1 },
        printqueue  => { type => 'varchar', length => 20 },
        printtype   => { type => 'varchar', length => 20 },
    ],

    primary_key_columns => [ 'printername' ],
);

1;

