package Koha::Schema::Systempreference::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Systempreference;

sub object_class { 'Koha::Schema::Systempreference' }

__PACKAGE__->make_manager_methods('systempreferences');

1;

