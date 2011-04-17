package Koha::Schema::Branchcategory::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Branchcategory;

sub object_class { 'Koha::Schema::Branchcategory' }

__PACKAGE__->make_manager_methods('branchcategories');

1;

