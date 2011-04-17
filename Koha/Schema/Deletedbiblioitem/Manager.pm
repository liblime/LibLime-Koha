package Koha::Schema::Deletedbiblioitem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Deletedbiblioitem;

sub object_class { 'Koha::Schema::Deletedbiblioitem' }

__PACKAGE__->make_manager_methods('deletedbiblioitems');

1;

