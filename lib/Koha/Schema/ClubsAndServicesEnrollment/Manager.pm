package Koha::Schema::ClubsAndServicesEnrollment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ClubsAndServicesEnrollment;

sub object_class { 'Koha::Schema::ClubsAndServicesEnrollment' }

__PACKAGE__->make_manager_methods('clubsAndServicesEnrollments');

1;

