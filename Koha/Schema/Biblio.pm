package Koha::Schema::Biblio;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

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
        aqorders => {
            class      => 'Koha::Schema::Aqorder',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        biblioitems => {
            class      => 'Koha::Schema::Biblioitem',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        borrowers => {
            map_class => 'Koha::Schema::HoldFillTarget',
            map_from  => 'biblio',
            map_to    => 'borrower',
            type      => 'many to many',
        },

        callslips => {
            class      => 'Koha::Schema::Callslip',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        periodical => {
            class                => 'Koha::Schema::Periodical',
            column_map           => { biblionumber => 'biblionumber' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },

        reserves => {
            class      => 'Koha::Schema::Reserve',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        summaries => {
            class      => 'Koha::Schema::Summary',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        tags_all => {
            class      => 'Koha::Schema::TagsAll',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },

        tags_index => {
            class      => 'Koha::Schema::TagsIndex',
            column_map => { biblionumber => 'biblionumber' },
            type       => 'one to many',
        },
    ],
);

1;

