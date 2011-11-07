package Koha::Schema::HoldFillTarget::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::HoldFillTarget;

sub object_class { 'Koha::Schema::HoldFillTarget' }

__PACKAGE__->make_manager_methods('hold_fill_targets');

1;

