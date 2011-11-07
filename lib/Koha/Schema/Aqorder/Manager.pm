package Koha::Schema::Aqorder::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Aqorder;

sub object_class { 'Koha::Schema::Aqorder' }

__PACKAGE__->make_manager_methods('aqorders');

1;

