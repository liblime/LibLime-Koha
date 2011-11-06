package Koha::Schema::ImportProfile;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'import_profiles',

    columns => [
        profile_id     => { type => 'serial', not_null => 1 },
        description    => { type => 'varchar', length => 50, not_null => 1 },
        matcher_id     => { type => 'integer' },
        template_id    => { type => 'integer' },
        overlay_action => { type => 'enum', check_in => [ 'replace', 'create_new', 'use_template', 'ignore' ], default => 'create_new', not_null => 1 },
        nomatch_action => { type => 'enum', check_in => [ 'create_new', 'ignore' ], default => 'create_new', not_null => 1 },
        parse_items    => { type => 'integer', default => 1 },
        item_action    => { type => 'enum', check_in => [ 'always_add', 'add_only_for_matches', 'add_only_for_new', 'ignore' ], default => 'always_add', not_null => 1 },
    ],

    primary_key_columns => [ 'profile_id' ],

    foreign_keys => [
        marc_matcher => {
            class       => 'Koha::Schema::MarcMatcher',
            key_columns => { matcher_id => 'matcher_id' },
        },
    ],

    relationships => [
        import_profile_subfield_actions => {
            class      => 'Koha::Schema::ImportProfileSubfieldAction',
            column_map => { profile_id => 'profile_id' },
            type       => 'one to many',
        },
    ],
);

1;

