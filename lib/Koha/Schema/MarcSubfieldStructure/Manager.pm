package Koha::Schema::MarcSubfieldStructure::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MarcSubfieldStructure;

sub object_class { 'Koha::Schema::MarcSubfieldStructure' }

__PACKAGE__->make_manager_methods('marc_subfield_structure');

1;

