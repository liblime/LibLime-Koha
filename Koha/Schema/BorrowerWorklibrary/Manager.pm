package Koha::Schema::BorrowerWorklibrary::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerWorklibrary;

sub object_class { 'Koha::Schema::BorrowerWorklibrary' }

__PACKAGE__->make_manager_methods('borrower_worklibrary');

1;

