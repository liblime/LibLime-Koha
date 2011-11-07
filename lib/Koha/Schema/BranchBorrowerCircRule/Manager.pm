package Koha::Schema::BranchBorrowerCircRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BranchBorrowerCircRule;

sub object_class { 'Koha::Schema::BranchBorrowerCircRule' }

__PACKAGE__->make_manager_methods('branch_borrower_circ_rules');

1;

