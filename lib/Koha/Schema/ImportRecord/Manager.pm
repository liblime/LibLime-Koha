package Koha::Schema::ImportRecord::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ImportRecord;

sub object_class { 'Koha::Schema::ImportRecord' }

__PACKAGE__->make_manager_methods('import_records');

1;

