package Koha::Schema::AuthType::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::AuthType;

sub object_class { 'Koha::Schema::AuthType' }

__PACKAGE__->make_manager_methods('auth_types');

1;

