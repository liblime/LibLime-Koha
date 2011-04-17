package Koha::Schema::PeriodicalSerial::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::PeriodicalSerial;

sub object_class { 'Koha::Schema::PeriodicalSerial' }

__PACKAGE__->make_manager_methods('periodical_serials');

1;

