package Koha::Schema::TagsIndex::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::TagsIndex;

sub object_class { 'Koha::Schema::TagsIndex' }

__PACKAGE__->make_manager_methods('tags_index');

1;

