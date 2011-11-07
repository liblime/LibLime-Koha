package Koha::Schema::LostItem;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'lost_items',

    columns => [
        id              => { type => 'serial', not_null => 1 },
        borrowernumber  => { type => 'integer', not_null => 1 },
        itemnumber      => { type => 'integer', not_null => 1 },
        biblionumber    => { type => 'integer', not_null => 1 },
        barcode         => { type => 'varchar', length => 20 },
        homebranch      => { type => 'varchar', length => 10 },
        holdingbranch   => { type => 'varchar', length => 10 },
        itemcallnumber  => { type => 'varchar', length => 100 },
        itemnotes       => { type => 'scalar', length => 16777215 },
        location        => { type => 'varchar', length => 80 },
        itemtype        => { type => 'varchar', length => 10, not_null => 1 },
        title           => { type => 'scalar', length => 16777215 },
        date_lost       => { type => 'date', not_null => 1 },
        claims_returned => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

