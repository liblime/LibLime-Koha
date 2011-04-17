package Koha::Schema::City;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'cities',

    columns => [
        cityid       => { type => 'serial', not_null => 1 },
        city_name    => { type => 'varchar', default => '', length => 100, not_null => 1 },
        city_zipcode => { type => 'varchar', length => 20 },
    ],

    primary_key_columns => [ 'cityid' ],
);

1;

