package Koha::Schema::MarcMatcher::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MarcMatcher;

sub object_class { 'Koha::Schema::MarcMatcher' }

__PACKAGE__->make_manager_methods('marc_matchers');

1;

