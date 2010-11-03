package C4::Model::SubscriptionSerialItem::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::SubscriptionSerialItem;

sub object_class { 'C4::Model::SubscriptionSerialItem' }

__PACKAGE__->make_manager_methods('subscription_serial_items');

1;

