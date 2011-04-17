package Koha::Schema::City::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::City;

sub object_class { 'Koha::Schema::City' }

__PACKAGE__->make_manager_methods('cities');

1;

