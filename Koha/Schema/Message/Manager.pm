package Koha::Schema::Message::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Message;

sub object_class { 'Koha::Schema::Message' }

__PACKAGE__->make_manager_methods('messages');

1;

