package Koha::Schema::UnstructuredSummaryHoldingsStatement::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::UnstructuredSummaryHoldingsStatement;

sub object_class { 'Koha::Schema::UnstructuredSummaryHoldingsStatement' }

__PACKAGE__->make_manager_methods('unstructured_summary_holdings_statements');

1;

