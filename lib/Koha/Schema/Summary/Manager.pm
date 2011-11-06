package Koha::Schema::Summary::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Summary;

sub object_class { 'Koha::Schema::Summary' }

__PACKAGE__->make_manager_methods('summaries');

1;

