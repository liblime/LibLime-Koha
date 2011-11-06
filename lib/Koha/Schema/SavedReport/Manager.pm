package Koha::Schema::SavedReport::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SavedReport;

sub object_class { 'Koha::Schema::SavedReport' }

__PACKAGE__->make_manager_methods('saved_reports');

1;

