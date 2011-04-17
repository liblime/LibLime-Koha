package Koha::Schema::SavedSql;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'saved_sql',

    columns => [
        id             => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer' },
        date_created   => { type => 'datetime' },
        last_modified  => { type => 'datetime' },
        savedsql       => { type => 'text', length => 65535 },
        last_run       => { type => 'datetime' },
        report_name    => { type => 'varchar', length => 255 },
        type           => { type => 'varchar', length => 255 },
        notes          => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

