package Koha::Schema::AuthSubfieldStructure::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::AuthSubfieldStructure;

sub object_class { 'Koha::Schema::AuthSubfieldStructure' }

__PACKAGE__->make_manager_methods('auth_subfield_structure');

1;

