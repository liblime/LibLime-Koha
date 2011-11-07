package Koha::Schema::Permission::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Permission;

sub object_class { 'Koha::Schema::Permission' }

__PACKAGE__->make_manager_methods('permissions');

1;

