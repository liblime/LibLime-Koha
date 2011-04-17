package Koha::Schema::Aqbookfund::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::Aqbookfund;

sub object_class { 'Koha::Schema::Aqbookfund' }

__PACKAGE__->make_manager_methods('aqbookfund');

1;

