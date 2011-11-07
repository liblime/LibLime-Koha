package Koha::Schema::DefaultBranchCircRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'default_branch_circ_rules',

    columns => [
        branchcode  => { type => 'varchar', length => 10, not_null => 1 },
        maxissueqty => { type => 'integer' },
        holdallowed => { type => 'integer' },
    ],

    primary_key_columns => [ 'branchcode' ],
);

1;

