package Koha::Schema::Virtualshelve::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Virtualshelve;

sub object_class { 'Koha::Schema::Virtualshelve' }

__PACKAGE__->make_manager_methods('virtualshelves');

1;

