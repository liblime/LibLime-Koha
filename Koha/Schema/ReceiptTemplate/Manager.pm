package Koha::Schema::ReceiptTemplate::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ReceiptTemplate;

sub object_class { 'Koha::Schema::ReceiptTemplate' }

__PACKAGE__->make_manager_methods('receipt_templates');

1;

