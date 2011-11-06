package Koha::Schema::InstructorCourseLink;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'instructor_course_link',

    columns => [
        instructor_course_link_id => { type => 'serial', not_null => 1 },
        course_id                 => { type => 'integer', default => '0', not_null => 1 },
        instructor_borrowernumber => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'instructor_course_link_id' ],
);

1;

