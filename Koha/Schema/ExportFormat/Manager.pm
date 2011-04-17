package Koha::Schema::ExportFormat::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ExportFormat;

sub object_class { 'Koha::Schema::ExportFormat' }

__PACKAGE__->make_manager_methods('export_format');

1;

