package Koha::Schema::TagsAll::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::TagsAll;

sub object_class { 'Koha::Schema::TagsAll' }

__PACKAGE__->make_manager_methods('tags_all');

1;

