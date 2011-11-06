package Koha::Schema::BorrowerWorklibrary;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_worklibrary',

    columns => [
        borrowernumber => { type => 'integer', not_null => 1 },
        branchcode     => { type => 'varchar', length => 10, not_null => 1 },
    ],

    primary_key_columns => [ 'borrowernumber', 'branchcode' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },
    ],
);

1;

