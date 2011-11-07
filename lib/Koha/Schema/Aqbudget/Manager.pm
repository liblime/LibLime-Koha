package Koha::Schema::Aqbudget::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Aqbudget;

sub object_class { 'Koha::Schema::Aqbudget' }

__PACKAGE__->make_manager_methods('aqbudget');

1;

