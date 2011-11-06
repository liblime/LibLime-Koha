package Koha::Schema::Biblioitem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Biblioitem;

sub object_class { 'Koha::Schema::Biblioitem' }

__PACKAGE__->make_manager_methods('biblioitems');

1;

