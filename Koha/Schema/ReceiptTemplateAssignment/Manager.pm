package Koha::Schema::ReceiptTemplateAssignment::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ReceiptTemplateAssignment;

sub object_class { 'Koha::Schema::ReceiptTemplateAssignment' }

__PACKAGE__->make_manager_methods('receipt_template_assignments');

1;

