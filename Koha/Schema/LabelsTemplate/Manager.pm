package Koha::Schema::LabelsTemplate::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LabelsTemplate;

sub object_class { 'Koha::Schema::LabelsTemplate' }

__PACKAGE__->make_manager_methods('labels_templates');

1;

