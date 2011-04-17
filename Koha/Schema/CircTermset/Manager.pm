package Koha::Schema::CircTermset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::CircTermset;

sub object_class { 'Koha::Schema::CircTermset' }

__PACKAGE__->make_manager_methods('circ_termsets');

1;

