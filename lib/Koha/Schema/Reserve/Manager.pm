package Koha::Schema::Reserve::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Reserve;

sub object_class { 'Koha::Schema::Reserve' }

__PACKAGE__->make_manager_methods('reserves');

1;

