package Koha::Schema::MatchpointComponent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MatchpointComponent;

sub object_class { 'Koha::Schema::MatchpointComponent' }

__PACKAGE__->make_manager_methods('matchpoint_components');

1;

