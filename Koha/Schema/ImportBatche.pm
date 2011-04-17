package Koha::Schema::ImportBatche;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'import_batches',

    columns => [
        import_batch_id  => { type => 'serial', not_null => 1 },
        matcher_id       => { type => 'integer' },
        template_id      => { type => 'integer' },
        branchcode       => { type => 'varchar', length => 10 },
        num_biblios      => { type => 'integer', default => '0', not_null => 1 },
        num_items        => { type => 'integer', default => '0', not_null => 1 },
        upload_timestamp => { type => 'timestamp', not_null => 1 },
        overlay_action   => { type => 'enum', check_in => [ 'replace', 'create_new', 'use_template', 'ignore' ], default => 'create_new', not_null => 1 },
        nomatch_action   => { type => 'enum', check_in => [ 'create_new', 'ignore' ], default => 'create_new', not_null => 1 },
        item_action      => { type => 'enum', check_in => [ 'always_add', 'add_only_for_matches', 'add_only_for_new', 'ignore' ], default => 'always_add', not_null => 1 },
        import_status    => { type => 'enum', check_in => [ 'staging', 'staged', 'importing', 'imported', 'reverting', 'reverted', 'cleaned' ], default => 'staging', not_null => 1 },
        batch_type       => { type => 'enum', check_in => [ 'batch', 'z3950' ], default => 'batch', not_null => 1 },
        file_name        => { type => 'varchar', length => 100 },
        comments         => { type => 'scalar', length => 16777215 },
    ],

    primary_key_columns => [ 'import_batch_id' ],

    relationships => [
        import_records => {
            class      => 'Koha::Schema::ImportRecord',
            column_map => { import_batch_id => 'import_batch_id' },
            type       => 'one to many',
        },
    ],
);

1;

