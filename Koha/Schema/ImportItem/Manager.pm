package Koha::Schema::ImportItem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ImportItem;

sub object_class { 'Koha::Schema::ImportItem' }

__PACKAGE__->make_manager_methods('import_items');

1;

