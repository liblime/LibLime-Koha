package Koha::Schema::Callslip::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Callslip;

sub object_class { 'Koha::Schema::Callslip' }

__PACKAGE__->make_manager_methods('callslips');

1;

