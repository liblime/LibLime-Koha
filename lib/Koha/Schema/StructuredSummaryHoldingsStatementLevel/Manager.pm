package Koha::Schema::StructuredSummaryHoldingsStatementLevel::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::StructuredSummaryHoldingsStatementLevel;

sub object_class { 'Koha::Schema::StructuredSummaryHoldingsStatementLevel' }

__PACKAGE__->make_manager_methods('structured_summary_holdings_statement_levels');

1;

