package Koha::Schema::Payment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Payment;

sub object_class { 'Koha::Schema::Payment' }

__PACKAGE__->make_manager_methods('payments');

1;

