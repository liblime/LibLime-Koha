package C4::Schema::SubscriptionSerial::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::SubscriptionSerial;

sub object_class { 'C4::Schema::SubscriptionSerial' }

__PACKAGE__->make_manager_methods('subscription_serials');

1;

