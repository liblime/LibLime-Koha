package Koha::Schema::Ethnicity;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'ethnicity',

    columns => [
        code => { type => 'varchar', length => 10, not_null => 1 },
        name => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'code' ],
);

1;

