package Koha::Schema::Zebraqueue::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Zebraqueue;

sub object_class { 'Koha::Schema::Zebraqueue' }

__PACKAGE__->make_manager_methods('zebraqueue');

1;

