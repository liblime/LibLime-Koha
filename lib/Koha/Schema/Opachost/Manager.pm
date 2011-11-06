package Koha::Schema::Opachost::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Opachost;

sub object_class { 'Koha::Schema::Opachost' }

__PACKAGE__->make_manager_methods('opachosts');

1;

