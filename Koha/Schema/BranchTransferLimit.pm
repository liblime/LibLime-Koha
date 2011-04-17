package Koha::Schema::BranchTransferLimit;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'branch_transfer_limits',

    columns => [
        limitId    => { type => 'serial', not_null => 1 },
        toBranch   => { type => 'varchar', length => 10, not_null => 1 },
        fromBranch => { type => 'varchar', length => 10, not_null => 1 },
        itemtype   => { type => 'varchar', length => 10 },
        ccode      => { type => 'varchar', length => 10 },
    ],

    primary_key_columns => [ 'limitId' ],
);

1;

