package Koha::Schema::ImportRecord;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'import_records',

    columns => [
        import_record_id => { type => 'serial', not_null => 1 },
        import_batch_id  => { type => 'integer', not_null => 1 },
        branchcode       => { type => 'varchar', length => 10 },
        record_sequence  => { type => 'integer', default => '0', not_null => 1 },
        upload_timestamp => { type => 'timestamp', not_null => 1 },
        import_date      => { type => 'date' },
        marc             => { type => 'scalar', length => 4294967295, not_null => 1 },
        marcxml          => { type => 'scalar', length => 4294967295, not_null => 1 },
        marcxml_old      => { type => 'scalar', length => 4294967295, not_null => 1 },
        record_type      => { type => 'enum', check_in => [ 'biblio', 'auth', 'holdings' ], default => 'biblio', not_null => 1 },
        overlay_status   => { type => 'enum', check_in => [ 'no_match', 'auto_match', 'manual_match', 'match_applied' ], default => 'no_match', not_null => 1 },
        status           => { type => 'enum', check_in => [ 'error', 'staged', 'imported', 'reverted', 'items_reverted', 'ignored' ], default => 'staged', not_null => 1 },
        import_error     => { type => 'scalar', length => 16777215 },
        encoding         => { type => 'varchar', default => '', length => 40, not_null => 1 },
        z3950random      => { type => 'varchar', length => 40 },
    ],

    primary_key_columns => [ 'import_record_id' ],

    foreign_keys => [
        import_batche => {
            class       => 'Koha::Schema::ImportBatche',
            key_columns => { import_batch_id => 'import_batch_id' },
        },
    ],

    relationships => [
        import_items => {
            class      => 'Koha::Schema::ImportItem',
            column_map => { import_record_id => 'import_record_id' },
            type       => 'one to many',
        },
    ],
);

1;

