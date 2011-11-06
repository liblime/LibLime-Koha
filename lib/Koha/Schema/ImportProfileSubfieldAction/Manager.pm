package Koha::Schema::ImportProfileSubfieldAction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ImportProfileSubfieldAction;

sub object_class { 'Koha::Schema::ImportProfileSubfieldAction' }

__PACKAGE__->make_manager_methods('import_profile_subfield_actions');

1;

