package Koha::Schema::Letter;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'letter',

    columns => [
        module  => { type => 'varchar', length => 20, not_null => 1 },
        code    => { type => 'varchar', length => 20, not_null => 1 },
        name    => { type => 'varchar', default => '', length => 100, not_null => 1 },
        title   => { type => 'varchar', default => '', length => 200, not_null => 1 },
        content => { type => 'text', length => 65535 },
        ttcode  => { type => 'varchar', length => 20 },
    ],

    primary_key_columns => [ 'module', 'code' ],

    relationships => [
        message_transports => {
            class      => 'Koha::Schema::MessageTransport',
            column_map => { code   => 'letter_code', module => 'letter_module' },
            type       => 'one to many',
        },
    ],
);

1;

