package C4::Model::PeriodicalSerial::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use C4::Model::PeriodicalSerial;

sub object_class { 'C4::Model::PeriodicalSerial' }

__PACKAGE__->make_manager_methods('periodical_serials');

1;

