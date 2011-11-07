package Koha::Schema::BranchItemRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'branch_item_rules',

    columns => [
        branchcode  => { type => 'varchar', length => 10, not_null => 1 },
        itemtype    => { type => 'varchar', length => 10, not_null => 1 },
        holdallowed => { type => 'integer' },
    ],

    primary_key_columns => [ 'itemtype', 'branchcode' ],

    foreign_keys => [
        itemtype_obj => {
            class       => 'Koha::Schema::Itemtype',
            key_columns => { itemtype => 'itemtype' },
        },
    ],
);

1;

