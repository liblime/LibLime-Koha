package Koha::Schema::Overduerule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Overduerule;

sub object_class { 'Koha::Schema::Overduerule' }

__PACKAGE__->make_manager_methods('overduerules');

1;

