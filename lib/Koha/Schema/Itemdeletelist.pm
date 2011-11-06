package Koha::Schema::Itemdeletelist;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'itemdeletelist',

    columns => [
        list_id      => { type => 'integer', not_null => 1 },
        itemnumber   => { type => 'integer', not_null => 1 },
        biblionumber => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'list_id', 'itemnumber' ],
);

1;

