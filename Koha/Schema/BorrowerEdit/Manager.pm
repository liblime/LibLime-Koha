package Koha::Schema::BorrowerEdit::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerEdit;

sub object_class { 'Koha::Schema::BorrowerEdit' }

__PACKAGE__->make_manager_methods('borrower_edits');

1;

