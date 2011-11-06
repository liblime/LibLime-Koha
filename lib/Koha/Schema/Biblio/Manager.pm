package Koha::Schema::Biblio::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Biblio;

sub object_class { 'Koha::Schema::Biblio' }

__PACKAGE__->make_manager_methods('biblio');

1;

