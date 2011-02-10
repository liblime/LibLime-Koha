package C4::Schema::Biblioitem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::Biblioitem;

sub object_class { 'C4::Schema::Biblioitem' }

__PACKAGE__->make_manager_methods('biblioitems');

1;

