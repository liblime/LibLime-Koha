package Koha::Schema::AuthTagStructure;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'auth_tag_structure',

    columns => [
        authtypecode     => { type => 'varchar', length => 10, not_null => 1 },
        tagfield         => { type => 'varchar', length => 3, not_null => 1 },
        liblibrarian     => { type => 'varchar', default => '', length => 255, not_null => 1 },
        libopac          => { type => 'varchar', default => '', length => 255, not_null => 1 },
        repeatable       => { type => 'integer', default => '0', not_null => 1 },
        mandatory        => { type => 'integer', default => '0', not_null => 1 },
        authorised_value => { type => 'varchar', length => 10 },
    ],

    primary_key_columns => [ 'authtypecode', 'tagfield' ],

    foreign_keys => [
        auth_type => {
            class       => 'Koha::Schema::AuthType',
            key_columns => { authtypecode => 'authtypecode' },
        },
    ],
);

1;

