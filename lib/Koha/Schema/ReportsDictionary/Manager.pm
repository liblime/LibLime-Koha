package Koha::Schema::ReportsDictionary::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ReportsDictionary;

sub object_class { 'Koha::Schema::ReportsDictionary' }

__PACKAGE__->make_manager_methods('reports_dictionary');

1;

