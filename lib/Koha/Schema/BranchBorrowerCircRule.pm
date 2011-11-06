package Koha::Schema::BranchBorrowerCircRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'branch_borrower_circ_rules',

    columns => [
        branchcode   => { type => 'varchar', length => 10, not_null => 1 },
        categorycode => { type => 'varchar', length => 10, not_null => 1 },
        maxissueqty  => { type => 'integer' },
    ],

    primary_key_columns => [ 'categorycode', 'branchcode' ],

    foreign_keys => [
        category => {
            class       => 'Koha::Schema::Category',
            key_columns => { categorycode => 'categorycode' },
        },
    ],
);

1;

