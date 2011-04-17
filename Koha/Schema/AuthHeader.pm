package Koha::Schema::AuthHeader;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'auth_header',

    columns => [
        authid       => { type => 'bigserial', not_null => 1 },
        authtypecode => { type => 'varchar', default => '', length => 10, not_null => 1 },
        datecreated  => { type => 'date' },
        datemodified => { type => 'date' },
        origincode   => { type => 'varchar', length => 20 },
        authtrees    => { type => 'scalar', length => 16777215 },
        marc         => { type => 'blob', length => 65535 },
        linkid       => { type => 'bigint' },
        marcxml      => { type => 'scalar', length => 4294967295, not_null => 1 },
    ],

    primary_key_columns => [ 'authid' ],
);

1;

