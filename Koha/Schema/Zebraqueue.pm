package Koha::Schema::Zebraqueue;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'zebraqueue',

    columns => [
        id                 => { type => 'serial', not_null => 1 },
        biblio_auth_number => { type => 'bigint', default => '0', not_null => 1 },
        operation          => { type => 'character', default => '', length => 20, not_null => 1 },
        server             => { type => 'character', default => '', length => 20, not_null => 1 },
        done               => { type => 'integer', default => '0', not_null => 1 },
        time               => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

