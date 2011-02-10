package C4::Schema::Biblio::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::Biblio;

sub object_class { 'C4::Schema::Biblio' }

__PACKAGE__->make_manager_methods('biblio');

1;

