package Koha::Schema::Item::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Item;

sub object_class { 'Koha::Schema::Item' }

__PACKAGE__->make_manager_methods('items');

1;

