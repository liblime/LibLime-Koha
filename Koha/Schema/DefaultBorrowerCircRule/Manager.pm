package Koha::Schema::DefaultBorrowerCircRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::DefaultBorrowerCircRule;

sub object_class { 'Koha::Schema::DefaultBorrowerCircRule' }

__PACKAGE__->make_manager_methods('default_borrower_circ_rules');

1;

