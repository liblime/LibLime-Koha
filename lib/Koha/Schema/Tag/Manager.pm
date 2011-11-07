package Koha::Schema::Tag::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Tag;

sub object_class { 'Koha::Schema::Tag' }

__PACKAGE__->make_manager_methods('tags');

1;

