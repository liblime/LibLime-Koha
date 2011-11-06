package Koha::Schema::CircTermDate::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::CircTermDate;

sub object_class { 'Koha::Schema::CircTermDate' }

__PACKAGE__->make_manager_methods('circ_term_dates');

1;

