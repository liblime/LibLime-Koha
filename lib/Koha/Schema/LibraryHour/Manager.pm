package Koha::Schema::LibraryHour::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LibraryHour;

sub object_class { 'Koha::Schema::LibraryHour' }

__PACKAGE__->make_manager_methods('library_hours');

1;

