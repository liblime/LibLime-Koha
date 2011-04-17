package Koha::Schema::CourseReserve::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::CourseReserve;

sub object_class { 'Koha::Schema::CourseReserve' }

__PACKAGE__->make_manager_methods('course_reserves');

1;

