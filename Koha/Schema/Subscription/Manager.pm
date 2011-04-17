package Koha::Schema::Subscription::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Subscription;

sub object_class { 'Koha::Schema::Subscription' }

__PACKAGE__->make_manager_methods('subscriptions');

1;

