package Koha::Schema::Branchcategory;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'branchcategories',

    columns => [
        categorycode    => { type => 'varchar', length => 10, not_null => 1 },
        categoryname    => { type => 'varchar', length => 32 },
        codedescription => { type => 'scalar', length => 16777215 },
        categorytype    => { type => 'varchar', length => 16 },
    ],

    primary_key_columns => [ 'categorycode' ],

    relationships => [
        opachosts => {
            class      => 'Koha::Schema::Opachost',
            column_map => { categorycode => 'default_branchcategory' },
            type       => 'one to many',
        },
    ],
);

1;

