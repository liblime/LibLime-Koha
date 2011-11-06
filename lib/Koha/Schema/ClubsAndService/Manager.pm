package Koha::Schema::ClubsAndService::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ClubsAndService;

sub object_class { 'Koha::Schema::ClubsAndService' }

__PACKAGE__->make_manager_methods('clubsAndServices');

1;

