package Koha::Schema::Category::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Category;

sub object_class { 'Koha::Schema::Category' }

__PACKAGE__->make_manager_methods('categories');

1;

