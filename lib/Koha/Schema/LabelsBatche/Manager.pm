package Koha::Schema::LabelsBatche::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LabelsBatche;

sub object_class { 'Koha::Schema::LabelsBatche' }

__PACKAGE__->make_manager_methods('labels_batches');

1;

