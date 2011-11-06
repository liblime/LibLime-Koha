package Koha::Schema::Fee::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Fee;

sub object_class { 'Koha::Schema::Fee' }

__PACKAGE__->make_manager_methods('fees');

1;

