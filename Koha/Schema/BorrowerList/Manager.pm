package Koha::Schema::BorrowerList::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerList;

sub object_class { 'Koha::Schema::BorrowerList' }

__PACKAGE__->make_manager_methods('borrower_lists');

1;

