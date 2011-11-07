package Koha::Schema::Userflag::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Userflag;

sub object_class { 'Koha::Schema::Userflag' }

__PACKAGE__->make_manager_methods('userflags');

1;

