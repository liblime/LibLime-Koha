package Koha::Schema::Cours::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Cours;

sub object_class { 'Koha::Schema::Cours' }

__PACKAGE__->make_manager_methods('courses');

1;

