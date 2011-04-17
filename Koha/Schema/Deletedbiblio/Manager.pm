package Koha::Schema::Deletedbiblio::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Deletedbiblio;

sub object_class { 'Koha::Schema::Deletedbiblio' }

__PACKAGE__->make_manager_methods('deletedbiblio');

1;

