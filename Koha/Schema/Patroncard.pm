package Koha::Schema::Patroncard;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'patroncards',

    columns => [
        cardid         => { type => 'serial', not_null => 1 },
        batch_id       => { type => 'varchar', default => 1, length => 10, not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
        timestamp      => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'cardid' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },
    ],
);

1;

