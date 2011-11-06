package Koha::Schema::ImportBatche::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ImportBatche;

sub object_class { 'Koha::Schema::ImportBatche' }

__PACKAGE__->make_manager_methods('import_batches');

1;

