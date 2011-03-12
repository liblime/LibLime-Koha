package C4::Schema::Biblio;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'biblio',

    columns => [
        biblionumber  => { type => 'serial', not_null => 1 },
        frameworkcode => { type => 'varchar', default => '', length => 4, not_null => 1 },
        author        => { type => 'scalar', length => 16777215 },
        title         => { type => 'scalar', length => 16777215 },
        unititle      => { type => 'scalar', length => 16777215 },
        notes         => { type => 'scalar', length => 16777215 },
        serial        => { type => 'integer' },
        seriestitle   => { type => 'scalar', length => 16777215 },
        copyrightdate => { type => 'integer' },
        timestamp     => { type => 'timestamp', not_null => 1 },
        datecreated   => { type => 'date', not_null => 1 },
        abstract      => { type => 'scalar', length => 16777215 },
    ],

    primary_key_columns => [ 'biblionumber' ],

    relationships => [
        biblioitems => {
            class      => 'C4::Schema::Biblioitem',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        periodical => {
            class                => 'C4::Schema::Periodical',
            column_map           => { biblionumber => 'biblionumber' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },
    ],
);

1;

