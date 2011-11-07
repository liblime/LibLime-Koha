package Koha::Schema::MessageAttribute::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MessageAttribute;

sub object_class { 'Koha::Schema::MessageAttribute' }

__PACKAGE__->make_manager_methods('message_attributes');

1;

