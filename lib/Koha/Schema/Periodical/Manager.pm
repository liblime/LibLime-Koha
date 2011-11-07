package Koha::Schema::Periodical::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Periodical;

sub object_class { 'Koha::Schema::Periodical' }

__PACKAGE__->make_manager_methods('periodicals');

1;

