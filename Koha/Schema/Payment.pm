package Koha::Schema::Payment;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'payments',

    columns => [
        id             => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
        branchcode     => { type => 'varchar', length => 10 },
        description    => { type => 'scalar', length => 16777215 },
        amount         => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
        accounttype    => { type => 'varchar', length => 16 },
        date           => { type => 'date' },
        unallocated    => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
        timestamp      => { type => 'timestamp', not_null => 1 },
        operator_id    => { type => 'integer' },
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
    ],
);

1;

