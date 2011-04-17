package Koha::Schema::Overduerule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'overduerules',

    columns => [
        branchcode   => { type => 'varchar', length => 10, not_null => 1 },
        categorycode => { type => 'varchar', length => 10, not_null => 1 },
        delay1       => { type => 'integer', default => '0' },
        letter1      => { type => 'varchar', length => 20 },
        debarred1    => { type => 'varchar', default => '0', length => 1 },
        delay2       => { type => 'integer', default => '0' },
        debarred2    => { type => 'varchar', default => '0', length => 1 },
        letter2      => { type => 'varchar', length => 20 },
        delay3       => { type => 'integer', default => '0' },
        letter3      => { type => 'varchar', length => 20 },
        debarred3    => { type => 'integer', default => '0' },
    ],

    primary_key_columns => [ 'branchcode', 'categorycode' ],
);

1;

