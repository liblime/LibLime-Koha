package Koha::Schema::Matchcheck::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Matchcheck;

sub object_class { 'Koha::Schema::Matchcheck' }

__PACKAGE__->make_manager_methods('matchchecks');

1;

