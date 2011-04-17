package Koha::Schema::Matchpoint;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'matchpoints',

    columns => [
        matcher_id    => { type => 'integer', not_null => 1 },
        matchpoint_id => { type => 'serial', not_null => 1 },
        search_index  => { type => 'varchar', default => '', length => 30, not_null => 1 },
        score         => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'matchpoint_id' ],

    foreign_keys => [
        marc_matcher => {
            class       => 'Koha::Schema::MarcMatcher',
            key_columns => { matcher_id => 'matcher_id' },
        },
    ],

    relationships => [
        matchchecks => {
            class      => 'Koha::Schema::Matchcheck',
            column_map => { matchpoint_id => 'source_matchpoint_id' },
            type       => 'one to many',
        },

        matchchecks_objs => {
            class      => 'Koha::Schema::Matchcheck',
            column_map => { matchpoint_id => 'target_matchpoint_id' },
            type       => 'one to many',
        },

        matchpoint_components => {
            class      => 'Koha::Schema::MatchpointComponent',
            column_map => { matchpoint_id => 'matchpoint_id' },
            type       => 'one to many',
        },
    ],
);

1;

