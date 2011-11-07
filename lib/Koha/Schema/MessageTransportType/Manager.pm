package Koha::Schema::MessageTransportType::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::MessageTransportType;

sub object_class { 'Koha::Schema::MessageTransportType' }

__PACKAGE__->make_manager_methods('message_transport_types');

1;

