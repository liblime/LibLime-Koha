package Koha::Schema::AuthorisedValue::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::AuthorisedValue;

sub object_class { 'Koha::Schema::AuthorisedValue' }

__PACKAGE__->make_manager_methods('authorised_values');

1;

