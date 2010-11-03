package C4::Model::Periodical::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::Periodical;

sub object_class { 'C4::Model::Periodical' }

__PACKAGE__->make_manager_methods('periodicals');

1;

