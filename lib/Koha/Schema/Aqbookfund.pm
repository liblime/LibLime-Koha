package Koha::Schema::Aqbookfund;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'aqbookfund',

    columns => [
        bookfundid    => { type => 'varchar', length => 10, not_null => 1 },
        bookfundname  => { type => 'scalar', length => 16777215 },
        bookfundgroup => { type => 'varchar', length => 5 },
        branchcode    => { type => 'varchar', length => 10, not_null => 1 },
    ],

    primary_key_columns => [ 'bookfundid', 'branchcode' ],
);

1;

