package Koha::Schema::FeeTransaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::FeeTransaction;

sub object_class { 'Koha::Schema::FeeTransaction' }

__PACKAGE__->make_manager_methods('fee_transactions');

1;

