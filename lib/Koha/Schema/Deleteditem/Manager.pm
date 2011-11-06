package Koha::Schema::Deleteditem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Deleteditem;

sub object_class { 'Koha::Schema::Deleteditem' }

__PACKAGE__->make_manager_methods('deleteditems');

1;

