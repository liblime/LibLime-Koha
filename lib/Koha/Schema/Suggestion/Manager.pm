package Koha::Schema::Suggestion::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Suggestion;

sub object_class { 'Koha::Schema::Suggestion' }

__PACKAGE__->make_manager_methods('suggestions');

1;

