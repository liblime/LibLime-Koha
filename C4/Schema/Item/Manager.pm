package C4::Schema::Item::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::Item;

sub object_class { 'C4::Schema::Item' }

__PACKAGE__->make_manager_methods('items');

1;

