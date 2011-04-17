package Koha::Schema::Xtag::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Xtag;

sub object_class { 'Koha::Schema::Xtag' }

__PACKAGE__->make_manager_methods('xtags');

1;

