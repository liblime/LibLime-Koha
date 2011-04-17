package Koha::Schema::CircPolicy::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::CircPolicy;

sub object_class { 'Koha::Schema::CircPolicy' }

__PACKAGE__->make_manager_methods('circ_policies');

1;

