package Koha::Schema::LanguageDescription;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'language_descriptions',

    columns => [
        subtag      => { type => 'varchar', length => 25 },
        type        => { type => 'varchar', length => 25 },
        lang        => { type => 'varchar', length => 25 },
        description => { type => 'varchar', length => 255 },
        id          => { type => 'serial', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

