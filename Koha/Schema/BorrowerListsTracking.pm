package Koha::Schema::BorrowerListsTracking;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_lists_tracking',

    columns => [
        list_id        => { type => 'integer', not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'list_id', 'borrowernumber' ],
);

1;

