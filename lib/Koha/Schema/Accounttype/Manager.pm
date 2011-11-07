package Koha::Schema::Accounttype::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Accounttype;

sub object_class { 'Koha::Schema::Accounttype' }

__PACKAGE__->make_manager_methods('accounttypes');

1;

