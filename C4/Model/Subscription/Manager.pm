package C4::Model::Subscription::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::Subscription;

sub object_class { 'C4::Model::Subscription' }

__PACKAGE__->make_manager_methods('subscriptions');

1;

