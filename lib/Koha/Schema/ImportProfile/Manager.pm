package Koha::Schema::ImportProfile::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ImportProfile;

sub object_class { 'Koha::Schema::ImportProfile' }

__PACKAGE__->make_manager_methods('import_profiles');

1;

