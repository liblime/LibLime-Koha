package Koha::Schema::DefaultBorrowerCircRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'default_borrower_circ_rules',

    columns => [
        categorycode => { type => 'varchar', length => 10, not_null => 1 },
        maxissueqty  => { type => 'integer' },
    ],

    primary_key_columns => [ 'categorycode' ],

    foreign_keys => [
        category => {
            class       => 'Koha::Schema::Category',
            key_columns => { categorycode => 'categorycode' },
            rel_type    => 'one to one',
        },
    ],
);

1;

