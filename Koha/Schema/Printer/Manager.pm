package Koha::Schema::Printer::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Printer;

sub object_class { 'Koha::Schema::Printer' }

__PACKAGE__->make_manager_methods('printers');

1;

