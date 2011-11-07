package Koha::Schema::ServicesThrottle;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'services_throttle',

    columns => [
        service_type  => { type => 'varchar', length => 10, not_null => 1 },
        service_count => { type => 'varchar', length => 45 },
    ],

    primary_key_columns => [ 'service_type' ],
);

1;

