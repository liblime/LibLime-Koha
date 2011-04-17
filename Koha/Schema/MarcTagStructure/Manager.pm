package Koha::Schema::MarcTagStructure::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MarcTagStructure;

sub object_class { 'Koha::Schema::MarcTagStructure' }

__PACKAGE__->make_manager_methods('marc_tag_structure');

1;

