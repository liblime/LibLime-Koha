package Koha::Schema::MatchpointComponent;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'matchpoint_components',

    columns => [
        matchpoint_id           => { type => 'integer', not_null => 1 },
        matchpoint_component_id => { type => 'serial', not_null => 1 },
        sequence                => { type => 'integer', default => '0', not_null => 1 },
        tag                     => { type => 'varchar', default => '', length => 3, not_null => 1 },
        subfields               => { type => 'varchar', default => '', length => 40, not_null => 1 },
        offset                  => { type => 'integer', default => '0', not_null => 1 },
        length                  => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'matchpoint_component_id' ],

    foreign_keys => [
        matchpoint => {
            class       => 'Koha::Schema::Matchpoint',
            key_columns => { matchpoint_id => 'matchpoint_id' },
        },
    ],
);

1;

