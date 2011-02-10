package C4::Schema::Periodical::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::Periodical;

sub object_class { 'C4::Schema::Periodical' }

__PACKAGE__->make_manager_methods('periodicals');

1;

