package Koha::Schema::AuthHeader::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::AuthHeader;

sub object_class { 'Koha::Schema::AuthHeader' }

__PACKAGE__->make_manager_methods('auth_header');

1;

