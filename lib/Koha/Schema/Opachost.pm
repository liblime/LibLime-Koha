package Koha::Schema::Opachost;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'opachosts',

    columns => [
        id                     => { type => 'serial', not_null => 1 },
        hostname               => { type => 'character', length => 127, not_null => 1 },
        css_url                => { type => 'character', length => 255 },
        default_branchcategory => { type => 'character', length => 10 },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'hostname' ],

    foreign_keys => [
        branchcategory => {
            class       => 'Koha::Schema::Branchcategory',
            key_columns => { default_branchcategory => 'categorycode' },
        },
    ],
);

1;

