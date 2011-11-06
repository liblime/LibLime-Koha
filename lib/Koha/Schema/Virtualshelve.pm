package Koha::Schema::Virtualshelve;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'virtualshelves',

    columns => [
        shelfnumber  => { type => 'serial', not_null => 1 },
        shelfname    => { type => 'varchar', length => 255 },
        owner        => { type => 'varchar', length => 80 },
        category     => { type => 'varchar', length => 1 },
        sortfield    => { type => 'varchar', length => 16 },
        lastmodified => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'shelfnumber' ],
);

1;

