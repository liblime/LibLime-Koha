package Koha::Schema::Cours;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'courses',

    columns => [
        course_id      => { type => 'serial', not_null => 1 },
        department     => { type => 'varchar', length => 20 },
        course_number  => { type => 'varchar', length => 255 },
        section        => { type => 'varchar', length => 255 },
        course_name    => { type => 'varchar', length => 255 },
        term           => { type => 'varchar', length => 20 },
        staff_note     => { type => 'scalar', length => 16777215 },
        public_note    => { type => 'scalar', length => 16777215 },
        students_count => { type => 'varchar', length => 20 },
        course_status  => { type => 'enum', check_in => [ 'enabled', 'disabled' ], default => 'enabled', not_null => 1 },
        timestamp      => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'course_id' ],
);

1;

