package Koha::Schema::TagsIndex;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'tags_index',

    columns => [
        term         => { type => 'varchar', length => 255, not_null => 1 },
        biblionumber => { type => 'integer', not_null => 1 },
        weight       => { type => 'integer', default => 1, not_null => 1 },
    ],

    primary_key_columns => [ 'term', 'biblionumber' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        tags_approval => {
            class       => 'Koha::Schema::TagsApproval',
            key_columns => { term => 'term' },
        },
    ],
);

1;

