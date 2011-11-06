package Koha::Schema::ExportFormat;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'export_format',

    columns => [
        export_format_id => { type => 'serial', not_null => 1 },
        profile          => { type => 'varchar', length => 255, not_null => 1 },
        description      => { type => 'scalar', length => 16777215, not_null => 1 },
        marcfields       => { type => 'scalar', length => 16777215, not_null => 1 },
    ],

    primary_key_columns => [ 'export_format_id' ],
);

1;

