package Koha::Schema::Overdueitemrule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Overdueitemrule;

sub object_class { 'Koha::Schema::Overdueitemrule' }

__PACKAGE__->make_manager_methods('overdueitemrules');

1;

