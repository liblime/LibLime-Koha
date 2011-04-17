package Koha::Schema::MessageTransport::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MessageTransport;

sub object_class { 'Koha::Schema::MessageTransport' }

__PACKAGE__->make_manager_methods('message_transports');

1;

