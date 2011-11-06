package Koha::Schema::Currency::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Currency;

sub object_class { 'Koha::Schema::Currency' }

__PACKAGE__->make_manager_methods('currency');

1;

