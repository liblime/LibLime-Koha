package Koha::Schema::SessionDefault::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SessionDefault;

sub object_class { 'Koha::Schema::SessionDefault' }

__PACKAGE__->make_manager_methods('session_defaults');

1;

