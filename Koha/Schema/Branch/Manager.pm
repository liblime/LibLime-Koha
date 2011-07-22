package Koha::Schema::Branch::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Branch;

sub object_class { 'Koha::Schema::Branch' }

__PACKAGE__->make_manager_methods('branches');

1;

