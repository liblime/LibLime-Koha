package C4::Model::Item::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::Item;

sub object_class { 'C4::Model::Item' }

__PACKAGE__->make_manager_methods('items');

1;

