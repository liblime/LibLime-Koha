package C4::Model::Biblioitem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::Biblioitem;

sub object_class { 'C4::Model::Biblioitem' }

__PACKAGE__->make_manager_methods('biblioitems');

1;

