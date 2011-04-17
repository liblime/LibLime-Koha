package Koha::Schema::BranchTransferLimit::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BranchTransferLimit;

sub object_class { 'Koha::Schema::BranchTransferLimit' }

__PACKAGE__->make_manager_methods('branch_transfer_limits');

1;

