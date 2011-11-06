package Koha::Schema::CircRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::CircRule;

sub object_class { 'Koha::Schema::CircRule' }

__PACKAGE__->make_manager_methods('circ_rules');

1;

