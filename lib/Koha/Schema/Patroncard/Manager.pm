package Koha::Schema::Patroncard::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Patroncard;

sub object_class { 'Koha::Schema::Patroncard' }

__PACKAGE__->make_manager_methods('patroncards');

1;

