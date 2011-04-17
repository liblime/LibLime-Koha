package Koha::Schema::SubscriptionSerial::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SubscriptionSerial;

sub object_class { 'Koha::Schema::SubscriptionSerial' }

__PACKAGE__->make_manager_methods('subscription_serials');

1;

