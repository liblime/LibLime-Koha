package Koha::Schema::PrintersProfile::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::PrintersProfile;

sub object_class { 'Koha::Schema::PrintersProfile' }

__PACKAGE__->make_manager_methods('printers_profile');

1;

