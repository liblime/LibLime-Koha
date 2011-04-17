package Koha::Schema::SavedReport;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'saved_reports',

    columns => [
        id        => { type => 'serial', not_null => 1 },
        report_id => { type => 'integer' },
        report    => { type => 'scalar', length => 4294967295 },
        date_run  => { type => 'datetime' },
    ],

    primary_key_columns => [ 'id' ],
);

1;

