package Koha::Schema::Itemdeletelist::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Itemdeletelist;

sub object_class { 'Koha::Schema::Itemdeletelist' }

__PACKAGE__->make_manager_methods('itemdeletelist');

1;

