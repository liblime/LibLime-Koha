package Koha::Schema::RepeatableHoliday;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'repeatable_holidays',

    columns => [
        id          => { type => 'serial', not_null => 1 },
        branchcode  => { type => 'varchar', default => '', length => 10, not_null => 1 },
        weekday     => { type => 'integer' },
        day         => { type => 'integer' },
        month       => { type => 'integer' },
        title       => { type => 'varchar', default => '', length => 50, not_null => 1 },
        description => { type => 'text', length => 65535, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

