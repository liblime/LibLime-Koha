package Koha::Schema::Itemstatu;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'itemstatus',

    columns => [
        statuscode_id => { type => 'serial', not_null => 1 },
        statuscode    => { type => 'varchar', default => '', length => 10, not_null => 1 },
        description   => { type => 'varchar', length => 25 },
        holdsallowed  => { type => 'integer', default => '0', not_null => 1 },
        holdsfilled   => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'statuscode_id' ],

    unique_key => [ 'statuscode' ],
);

1;

