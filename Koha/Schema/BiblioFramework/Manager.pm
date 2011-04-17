package Koha::Schema::BiblioFramework::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BiblioFramework;

sub object_class { 'Koha::Schema::BiblioFramework' }

__PACKAGE__->make_manager_methods('biblio_framework');

1;

