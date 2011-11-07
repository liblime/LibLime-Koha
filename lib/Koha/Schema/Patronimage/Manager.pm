package Koha::Schema::Patronimage::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Patronimage;

sub object_class { 'Koha::Schema::Patronimage' }

__PACKAGE__->make_manager_methods('patronimage');

1;

