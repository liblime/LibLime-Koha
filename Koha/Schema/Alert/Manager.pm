package Koha::Schema::Alert::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Alert;

sub object_class { 'Koha::Schema::Alert' }

__PACKAGE__->make_manager_methods('alert');

1;

