package Koha::Schema::ImportItem;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'import_items',

    columns => [
        import_items_id  => { type => 'serial', not_null => 1 },
        import_record_id => { type => 'integer', not_null => 1 },
        itemnumber       => { type => 'integer' },
        branchcode       => { type => 'varchar', length => 10 },
        status           => { type => 'enum', check_in => [ 'error', 'staged', 'imported', 'reverted', 'ignored' ], default => 'staged', not_null => 1 },
        marcxml          => { type => 'scalar', length => 4294967295, not_null => 1 },
        import_error     => { type => 'scalar', length => 16777215 },
    ],

    primary_key_columns => [ 'import_items_id' ],

    foreign_keys => [
        import_record => {
            class       => 'Koha::Schema::ImportRecord',
            key_columns => { import_record_id => 'import_record_id' },
        },
    ],
);

1;

