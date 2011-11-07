package Koha::Schema::AuthType;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'auth_types',

    columns => [
        authtypecode       => { type => 'varchar', length => 10, not_null => 1 },
        authtypetext       => { type => 'varchar', default => '', length => 255, not_null => 1 },
        auth_tag_to_report => { type => 'varchar', default => '', length => 3, not_null => 1 },
        summary            => { type => 'scalar', length => 16777215, not_null => 1 },
    ],

    primary_key_columns => [ 'authtypecode' ],

    relationships => [
        auth_tag_structure => {
            class      => 'Koha::Schema::AuthTagStructure',
            column_map => { authtypecode => 'authtypecode' },
            type       => 'one to many',
        },
    ],
);

1;

