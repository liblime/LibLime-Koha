package Koha::Schema::Issuingrule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'issuingrules',

    columns => [
        categorycode   => { type => 'varchar', length => 10, not_null => 1 },
        itemtype       => { type => 'varchar', length => 10, not_null => 1 },
        restrictedtype => { type => 'integer' },
        rentaldiscount => { type => 'numeric', precision => 28, scale => 6 },
        reservecharge  => { type => 'numeric', precision => 28, scale => 6 },
        fine           => { type => 'numeric', precision => 28, scale => 6 },
        firstremind    => { type => 'integer' },
        chargeperiod   => { type => 'integer' },
        accountsent    => { type => 'integer' },
        chargename     => { type => 'varchar', length => 100 },
        maxissueqty    => { type => 'integer' },
        issuelength    => { type => 'integer' },
        branchcode     => { type => 'varchar', length => 10, not_null => 1 },
        max_fine       => { type => 'numeric', precision => 28, scale => 6 },
        holdallowed    => { type => 'integer', default => 2 },
        max_holds      => { type => 'integer' },
    ],

    primary_key_columns => [ 'branchcode', 'categorycode', 'itemtype' ],
);

1;

