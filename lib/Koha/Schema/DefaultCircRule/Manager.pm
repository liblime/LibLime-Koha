package Koha::Schema::DefaultCircRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::DefaultCircRule;

sub object_class { 'Koha::Schema::DefaultCircRule' }

__PACKAGE__->make_manager_methods('default_circ_rules');

1;

