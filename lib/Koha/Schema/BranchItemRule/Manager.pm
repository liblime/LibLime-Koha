package Koha::Schema::BranchItemRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BranchItemRule;

sub object_class { 'Koha::Schema::BranchItemRule' }

__PACKAGE__->make_manager_methods('branch_item_rules');

1;

