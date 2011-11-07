package Koha::Schema::Matchcheck;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'matchchecks',

    columns => [
        matcher_id           => { type => 'integer', not_null => 1 },
        matchcheck_id        => { type => 'serial', not_null => 1 },
        source_matchpoint_id => { type => 'integer', not_null => 1 },
        target_matchpoint_id => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'matchcheck_id' ],

    foreign_keys => [
        marc_matcher => {
            class       => 'Koha::Schema::MarcMatcher',
            key_columns => { matcher_id => 'matcher_id' },
        },

        source => {
            class       => 'Koha::Schema::Matchpoint',
            key_columns => { source_matchpoint_id => 'matchpoint_id' },
        },

        target => {
            class       => 'Koha::Schema::Matchpoint',
            key_columns => { target_matchpoint_id => 'matchpoint_id' },
        },
    ],
);

1;

