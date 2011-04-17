package Koha::Schema::HoldFillTarget;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'hold_fill_targets',

    columns => [
        borrowernumber     => { type => 'integer', not_null => 1 },
        biblionumber       => { type => 'integer', not_null => 1 },
        itemnumber         => { type => 'integer', not_null => 1 },
        source_branchcode  => { type => 'varchar', length => 10 },
        item_level_request => { type => 'integer', default => '0', not_null => 1 },
        queue_sofar        => { type => 'text', length => 65535, not_null => 1 },
    ],

    primary_key_columns => [ 'itemnumber' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        item => {
            class       => 'Koha::Schema::Item',
            key_columns => { itemnumber => 'itemnumber' },
            rel_type    => 'one to one',
        },
    ],
);

1;

