package Koha::Schema::Z3950server::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Z3950server;

sub object_class { 'Koha::Schema::Z3950server' }

__PACKAGE__->make_manager_methods('z3950servers');

1;

