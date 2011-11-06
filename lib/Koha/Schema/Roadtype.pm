package Koha::Schema::Roadtype;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'roadtype',

    columns => [
        roadtypeid => { type => 'serial', not_null => 1 },
        road_type  => { type => 'varchar', default => '', length => 100, not_null => 1 },
    ],

    primary_key_columns => [ 'roadtypeid' ],
);

1;

