package Koha::Schema::OldReserve::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::OldReserve;

sub object_class { 'Koha::Schema::OldReserve' }

__PACKAGE__->make_manager_methods('old_reserves');

1;

