package Koha::Schema::FeeTransaction;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'fee_transactions',

    columns => [
        id             => { type => 'serial', not_null => 1 },
        fee_id         => { type => 'integer' },
        payment_id     => { type => 'integer' },
        borrowernumber => { type => 'integer', not_null => 1 },
        description    => { type => 'scalar', length => 16777215 },
        amount         => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
        accounttype    => { type => 'varchar', length => 16 },
        operator_id    => { type => 'integer' },
        branchcode     => { type => 'varchar', length => 10 },
        date           => { type => 'date' },
        timestamp      => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        accounttype_obj => {
            class       => 'Koha::Schema::Accounttype',
            key_columns => { accounttype => 'accounttype' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { operator_id => 'borrowernumber' },
        },

        borrower_obj => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        fee => {
            class       => 'Koha::Schema::Fee',
            key_columns => { fee_id => 'id' },
        },

        payment => {
            class       => 'Koha::Schema::Payment',
            key_columns => { payment_id => 'id' },
        },
    ],
);

1;

