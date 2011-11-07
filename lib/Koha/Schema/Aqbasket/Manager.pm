package Koha::Schema::Aqbasket::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Aqbasket;

sub object_class { 'Koha::Schema::Aqbasket' }

__PACKAGE__->make_manager_methods('aqbasket');

1;

