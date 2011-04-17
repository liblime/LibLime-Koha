package Koha::Schema::ClubsAndServicesArchetype::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ClubsAndServicesArchetype;

sub object_class { 'Koha::Schema::ClubsAndServicesArchetype' }

__PACKAGE__->make_manager_methods('clubsAndServicesArchetypes');

1;

