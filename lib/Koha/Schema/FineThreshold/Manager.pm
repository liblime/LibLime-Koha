package Koha::Schema::FineThreshold::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::FineThreshold;

sub object_class { 'Koha::Schema::FineThreshold' }

__PACKAGE__->make_manager_methods('fine_thresholds');

1;

