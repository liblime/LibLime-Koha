package Koha::Schema::CourseReserve;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'course_reserves',

    columns => [
        course_reserve_id   => { type => 'serial', not_null => 1 },
        course_id           => { type => 'integer', not_null => 1 },
        itemnumber          => { type => 'integer', not_null => 1 },
        staff_note          => { type => 'scalar', length => 16777215 },
        public_note         => { type => 'scalar', length => 16777215 },
        itemtype            => { type => 'varchar', length => 10 },
        ccode               => { type => 'varchar', length => 10 },
        location            => { type => 'varchar', length => 80 },
        branchcode          => { type => 'varchar', length => 10, not_null => 1 },
        original_itemtype   => { type => 'varchar', length => 10 },
        original_ccode      => { type => 'varchar', length => 10 },
        original_branchcode => { type => 'varchar', length => 10, not_null => 1 },
        original_location   => { type => 'varchar', length => 80 },
        timestamp           => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'course_reserve_id' ],
);

1;

