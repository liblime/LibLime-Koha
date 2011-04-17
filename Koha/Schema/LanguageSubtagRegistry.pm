package Koha::Schema::LanguageSubtagRegistry;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'language_subtag_registry',

    columns => [
        subtag      => { type => 'varchar', length => 25 },
        type        => { type => 'varchar', length => 25 },
        description => { type => 'varchar', length => 25 },
        added       => { type => 'date' },
        id          => { type => 'serial', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

