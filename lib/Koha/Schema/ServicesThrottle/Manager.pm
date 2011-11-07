package Koha::Schema::ServicesThrottle::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ServicesThrottle;

sub object_class { 'Koha::Schema::ServicesThrottle' }

__PACKAGE__->make_manager_methods('services_throttle');

1;

