package Koha::Schema::AuthTagStructure::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::AuthTagStructure;

sub object_class { 'Koha::Schema::AuthTagStructure' }

__PACKAGE__->make_manager_methods('auth_tag_structure');

1;

