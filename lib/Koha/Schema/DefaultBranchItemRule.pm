package Koha::Schema::DefaultBranchItemRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'default_branch_item_rules',

    columns => [
        itemtype    => { type => 'varchar', length => 10, not_null => 1 },
        holdallowed => { type => 'integer' },
    ],

    primary_key_columns => [ 'itemtype' ],

    foreign_keys => [
        itemtype_obj => {
            class       => 'Koha::Schema::Itemtype',
            key_columns => { itemtype => 'itemtype' },
            rel_type    => 'one to one',
        },
    ],
);

1;

