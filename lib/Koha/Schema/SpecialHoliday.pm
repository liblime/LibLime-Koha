package Koha::Schema::SpecialHoliday;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'special_holidays',

    columns => [
        id          => { type => 'serial', not_null => 1 },
        branchcode  => { type => 'varchar', default => '', length => 10, not_null => 1 },
        day         => { type => 'integer', default => '0', not_null => 1 },
        month       => { type => 'integer', default => '0', not_null => 1 },
        year        => { type => 'integer', default => '0', not_null => 1 },
        isexception => { type => 'integer', default => 1, not_null => 1 },
        title       => { type => 'varchar', default => '', length => 50, not_null => 1 },
        description => { type => 'text', length => 65535, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

