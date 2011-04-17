package Koha::Schema::BorrowerMessageTransportPreference::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerMessageTransportPreference;

sub object_class { 'Koha::Schema::BorrowerMessageTransportPreference' }

__PACKAGE__->make_manager_methods('borrower_message_transport_preferences');

1;

