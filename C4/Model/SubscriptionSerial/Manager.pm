package C4::Model::SubscriptionSerial::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::SubscriptionSerial;

sub object_class { 'C4::Model::SubscriptionSerial' }

__PACKAGE__->make_manager_methods('subscription_serials');

1;

