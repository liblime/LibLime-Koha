package C4::Model::Biblio::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::Biblio;

sub object_class { 'C4::Model::Biblio' }

__PACKAGE__->make_manager_methods('biblio');

1;

