package Koha::Schema::LostItem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LostItem;

sub object_class { 'Koha::Schema::LostItem' }

__PACKAGE__->make_manager_methods('lost_items');

1;

