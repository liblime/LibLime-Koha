package Koha::Schema::LibraryHour;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'library_hours',

    columns => [
        id         => { type => 'serial', not_null => 1 },
        branchcode => { type => 'varchar', length => 10 },
        date       => { type => 'date' },
        weekday    => { type => 'integer' },
        open       => { type => 'time', precision => 6, scale => 6 },
        close      => { type => 'time', precision => 6, scale => 6 },
    ],

    primary_key_columns => [ 'id' ],

    unique_keys => [
        [ 'branchcode', 'date' ],
        [ 'branchcode', 'weekday' ],
    ],
);

1;

