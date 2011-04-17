package Koha::Schema::Borrower::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Borrower;

sub object_class { 'Koha::Schema::Borrower' }

__PACKAGE__->make_manager_methods('borrowers');

1;

