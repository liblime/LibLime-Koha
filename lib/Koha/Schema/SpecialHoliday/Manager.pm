package Koha::Schema::SpecialHoliday::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SpecialHoliday;

sub object_class { 'Koha::Schema::SpecialHoliday' }

__PACKAGE__->make_manager_methods('special_holidays');

1;

