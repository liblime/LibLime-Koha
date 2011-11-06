package Koha::Schema::DefaultBranchItemRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::DefaultBranchItemRule;

sub object_class { 'Koha::Schema::DefaultBranchItemRule' }

__PACKAGE__->make_manager_methods('default_branch_item_rules');

1;

