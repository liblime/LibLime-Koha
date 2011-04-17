package Koha::Schema::DefaultBranchCircRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::DefaultBranchCircRule;

sub object_class { 'Koha::Schema::DefaultBranchCircRule' }

__PACKAGE__->make_manager_methods('default_branch_circ_rules');

1;

