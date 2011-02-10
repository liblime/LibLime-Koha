package C4::Schema::Subscription::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Schema::Subscription;

sub object_class { 'C4::Schema::Subscription' }

__PACKAGE__->make_manager_methods('subscriptions');

1;

