package Koha::Schema::ItemCirculationAlertPreference::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ItemCirculationAlertPreference;

sub object_class { 'Koha::Schema::ItemCirculationAlertPreference' }

__PACKAGE__->make_manager_methods('item_circulation_alert_preferences');

1;

