package Koha::Schema::Tag;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'tags',

    columns => [
        entry  => { type => 'varchar', length => 255, not_null => 1 },
        weight => { type => 'bigint', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'entry' ],
);

1;

