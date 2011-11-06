package Koha::Schema::Roadtype::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Roadtype;

sub object_class { 'Koha::Schema::Roadtype' }

__PACKAGE__->make_manager_methods('roadtype');

1;

