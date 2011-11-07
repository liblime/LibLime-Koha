package Koha::Schema::RepeatableHoliday::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::RepeatableHoliday;

sub object_class { 'Koha::Schema::RepeatableHoliday' }

__PACKAGE__->make_manager_methods('repeatable_holidays');

1;

