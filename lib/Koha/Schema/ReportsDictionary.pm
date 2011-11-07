package Koha::Schema::ReportsDictionary;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'reports_dictionary',

    columns => [
        id            => { type => 'serial', not_null => 1 },
        name          => { type => 'varchar', length => 255 },
        description   => { type => 'text', length => 65535 },
        date_created  => { type => 'datetime' },
        date_modified => { type => 'datetime' },
        saved_sql     => { type => 'text', length => 65535 },
        area          => { type => 'integer' },
    ],

    primary_key_columns => [ 'id' ],
);

1;

