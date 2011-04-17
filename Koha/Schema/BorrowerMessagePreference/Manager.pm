package Koha::Schema::BorrowerMessagePreference::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerMessagePreference;

sub object_class { 'Koha::Schema::BorrowerMessagePreference' }

__PACKAGE__->make_manager_methods('borrower_message_preferences');

1;

