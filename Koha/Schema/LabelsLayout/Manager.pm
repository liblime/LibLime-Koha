package Koha::Schema::LabelsLayout::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LabelsLayout;

sub object_class { 'Koha::Schema::LabelsLayout' }

__PACKAGE__->make_manager_methods('labels_layouts');

1;

