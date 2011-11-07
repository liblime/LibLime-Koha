package Koha::Schema::MarcMatcher;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'marc_matchers',

    columns => [
        matcher_id  => { type => 'serial', not_null => 1 },
        code        => { type => 'varchar', default => '', length => 10, not_null => 1 },
        description => { type => 'varchar', default => '', length => 255, not_null => 1 },
        record_type => { type => 'varchar', default => 'biblio', length => 10, not_null => 1 },
        threshold   => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'matcher_id' ],

    relationships => [
        import_profiles => {
            class      => 'Koha::Schema::ImportProfile',
            column_map => { matcher_id => 'matcher_id' },
            type       => 'one to many',
        },

        matchchecks => {
            class      => 'Koha::Schema::Matchcheck',
            column_map => { matcher_id => 'matcher_id' },
            type       => 'one to many',
        },

        matchpoints => {
            class      => 'Koha::Schema::Matchpoint',
            column_map => { matcher_id => 'matcher_id' },
            type       => 'one to many',
        },
    ],
);

1;

