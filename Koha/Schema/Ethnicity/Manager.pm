package Koha::Schema::Ethnicity::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Ethnicity;

sub object_class { 'Koha::Schema::Ethnicity' }

__PACKAGE__->make_manager_methods('ethnicity');

1;

