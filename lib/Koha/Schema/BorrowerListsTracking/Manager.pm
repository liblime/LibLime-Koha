package Koha::Schema::BorrowerListsTracking::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerListsTracking;

sub object_class { 'Koha::Schema::BorrowerListsTracking' }

__PACKAGE__->make_manager_methods('borrower_lists_tracking');

1;

