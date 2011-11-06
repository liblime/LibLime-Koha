package Koha::Schema::FineThreshold;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'fine_thresholds',

    columns => [
        id              => { type => 'serial', not_null => 1 },
        name            => { type => 'varchar', length => 50, not_null => 1 },
        branchcode      => { type => 'varchar', length => 10 },
        itemtype        => { type => 'varchar', length => 10 },
        patron_category => { type => 'varchar', length => 10 },
        accounttype     => { type => 'varchar', length => 16 },
        amount          => { type => 'numeric', default => '0.000000', precision => 28, scale => 6 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

