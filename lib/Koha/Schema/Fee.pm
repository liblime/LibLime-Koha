package Koha::Schema::Fee;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'fees',

    columns => [
        id             => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
        itemnumber     => { type => 'integer' },
        branchcode     => { type => 'varchar', length => 10 },
        description    => { type => 'scalar', length => 16777215 },
        curr_totaldue  => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
        orig_totaldue  => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
        date           => { type => 'date' },
        accounttype    => { type => 'varchar', length => 16 },
        notify_id      => { type => 'integer' },
        notify_level   => { type => 'integer', default => '0', not_null => 1 },
        dispute        => { type => 'scalar', length => 16777215 },
        last_updated   => { type => 'timestamp', not_null => 1 },
        orig_timestamp => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        accounttype_obj => {
            class       => 'Koha::Schema::Accounttype',
            key_columns => { accounttype => 'accounttype' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        item => {
            class       => 'Koha::Schema::Item',
            key_columns => { itemnumber => 'itemnumber' },
        },
    ],
);

1;

