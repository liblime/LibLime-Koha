package Koha::Schema::TagsAll;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'tags_all',

    columns => [
        tag_id         => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer', not_null => 1 },
        biblionumber   => { type => 'integer', not_null => 1 },
        term           => { type => 'varchar', length => 255, not_null => 1 },
        language       => { type => 'integer' },
        date_created   => { type => 'datetime', not_null => 1 },
    ],

    primary_key_columns => [ 'tag_id' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },
    ],
);

1;

