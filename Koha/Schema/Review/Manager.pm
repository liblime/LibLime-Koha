package Koha::Schema::Review::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Review;

sub object_class { 'Koha::Schema::Review' }

__PACKAGE__->make_manager_methods('reviews');

1;

