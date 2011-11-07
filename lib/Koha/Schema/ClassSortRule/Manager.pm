package Koha::Schema::ClassSortRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ClassSortRule;

sub object_class { 'Koha::Schema::ClassSortRule' }

__PACKAGE__->make_manager_methods('class_sort_rules');

1;

