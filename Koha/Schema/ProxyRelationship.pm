package Koha::Schema::ProxyRelationship;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'proxy_relationships',

    columns => [
        proxy_relationship_id => { type => 'serial', not_null => 1 },
        borrowernumber        => { type => 'integer', not_null => 1 },
        proxy_borrowernumber  => { type => 'integer', not_null => 1 },
        date_expires          => { type => 'date' },
        active                => { type => 'integer', default => '0', not_null => 1 },
        timestamp             => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'proxy_relationship_id' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        proxy => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { proxy_borrowernumber => 'borrowernumber' },
        },
    ],
);

1;

