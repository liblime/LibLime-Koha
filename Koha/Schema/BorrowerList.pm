package Koha::Schema::BorrowerList;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_lists',

    columns => [
        list_id    => { type => 'serial', not_null => 1 },
        list_name  => { type => 'varchar', length => 100, not_null => 1 },
        list_owner => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'list_id' ],

    unique_key => [ 'list_name', 'list_owner' ],
);

1;

