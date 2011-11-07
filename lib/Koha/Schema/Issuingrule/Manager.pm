package Koha::Schema::Issuingrule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Issuingrule;

sub object_class { 'Koha::Schema::Issuingrule' }

__PACKAGE__->make_manager_methods('issuingrules');

1;

