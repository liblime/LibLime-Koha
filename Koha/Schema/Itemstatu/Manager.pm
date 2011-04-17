package Koha::Schema::Itemstatu::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Itemstatu;

sub object_class { 'Koha::Schema::Itemstatu' }

__PACKAGE__->make_manager_methods('itemstatus');

1;

