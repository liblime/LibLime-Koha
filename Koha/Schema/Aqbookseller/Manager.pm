package Koha::Schema::Aqbookseller::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Aqbookseller;

sub object_class { 'Koha::Schema::Aqbookseller' }

__PACKAGE__->make_manager_methods('aqbooksellers');

1;

