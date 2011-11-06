package Koha::Schema::ImportProfileSubfieldAction;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'import_profile_subfield_actions',

    columns => [
        profile_id => { type => 'integer', not_null => 1 },
        tag        => { type => 'character', length => 3, not_null => 1 },
        subfield   => { type => 'character', length => 1, not_null => 1 },
        action     => { type => 'enum', check_in => [ 'add_always', 'add', 'delete' ] },
        contents   => { type => 'varchar', length => 255 },
    ],

    primary_key_columns => [ 'profile_id', 'tag', 'subfield' ],

    foreign_keys => [
        import_profile => {
            class       => 'Koha::Schema::ImportProfile',
            key_columns => { profile_id => 'profile_id' },
        },
    ],
);

1;

