package Koha::Schema::BorrowerEdit;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_edits',

    columns => [
        id             => { type => 'serial', not_null => 1 },
        timestamp      => { type => 'timestamp', not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
        staffnumber    => { type => 'integer', not_null => 1 },
        field          => { type => 'text', length => 65535, not_null => 1 },
        before_value   => { type => 'scalar', length => 16777215 },
        after_value    => { type => 'scalar', length => 16777215 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

