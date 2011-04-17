package Koha::Schema::CircRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'circ_rules',

    columns => [
        id               => { type => 'serial', not_null => 1 },
        categorycode     => { type => 'varchar', length => 10 },
        branchcode       => { type => 'varchar', length => 10 },
        itemtype         => { type => 'varchar', length => 10 },
        circ_policies_id => { type => 'integer', not_null => 1 },
        circ_termsets_id => { type => 'integer' },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'categorycode', 'branchcode', 'itemtype' ],

    foreign_keys => [
        category => {
            class       => 'Koha::Schema::Category',
            key_columns => { categorycode => 'categorycode' },
        },

        circ_policies => {
            class       => 'Koha::Schema::CircPolicy',
            key_columns => { circ_policies_id => 'id' },
        },

        circ_termsets => {
            class       => 'Koha::Schema::CircTermset',
            key_columns => { circ_termsets_id => 'id' },
        },

        itemtype_obj => {
            class       => 'Koha::Schema::Itemtype',
            key_columns => { itemtype => 'itemtype' },
        },
    ],
);

1;

