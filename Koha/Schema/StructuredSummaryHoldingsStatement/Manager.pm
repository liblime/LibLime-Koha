package Koha::Schema::StructuredSummaryHoldingsStatement::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::StructuredSummaryHoldingsStatement;

sub object_class { 'Koha::Schema::StructuredSummaryHoldingsStatement' }

__PACKAGE__->make_manager_methods('structured_summary_holdings_statements');

1;

