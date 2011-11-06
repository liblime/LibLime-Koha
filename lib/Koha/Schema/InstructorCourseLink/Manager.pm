package Koha::Schema::InstructorCourseLink::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::InstructorCourseLink;

sub object_class { 'Koha::Schema::InstructorCourseLink' }

__PACKAGE__->make_manager_methods('instructor_course_link');

1;

