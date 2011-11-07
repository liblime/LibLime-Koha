package Koha::Schema::BorrowerAttributeType::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::BorrowerAttributeType;

sub object_class { 'Koha::Schema::BorrowerAttributeType' }

__PACKAGE__->make_manager_methods('borrower_attribute_types');

1;

