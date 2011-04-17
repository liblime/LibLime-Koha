package Koha::Schema::Itemtype::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Itemtype;

sub object_class { 'Koha::Schema::Itemtype' }

__PACKAGE__->make_manager_methods('itemtypes');

1;

