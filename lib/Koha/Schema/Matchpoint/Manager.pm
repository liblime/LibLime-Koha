package Koha::Schema::Matchpoint::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Matchpoint;

sub object_class { 'Koha::Schema::Matchpoint' }

__PACKAGE__->make_manager_methods('matchpoints');

1;

