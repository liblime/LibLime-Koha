package Koha::Schema::Letter::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Letter;

sub object_class { 'Koha::Schema::Letter' }

__PACKAGE__->make_manager_methods('letter');

1;

