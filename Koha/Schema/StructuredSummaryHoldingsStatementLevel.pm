package Koha::Schema::StructuredSummaryHoldingsStatementLevel;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'structured_summary_holdings_statement_levels',

    columns => [
        id                                       => { type => 'serial', not_null => 1 },
        structured_summary_holdings_statement_id => { type => 'integer', default => '0' },
        level                                    => { type => 'integer', default => '0', not_null => 1 },
        beginning_label                          => { type => 'character', default => '', length => 32, not_null => 1 },
        beginning_value                          => { type => 'character', default => '', length => 32, not_null => 1 },
        ending_label                             => { type => 'character', default => '', length => 32, not_null => 1 },
        ending_value                             => { type => 'character', default => '', length => 32, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        structured_summary_holdings_statement => {
            class       => 'Koha::Schema::StructuredSummaryHoldingsStatement',
            key_columns => {
                structured_summary_holdings_statement_id => 'structured_summary_holdings_statement_id',
            },
        },
    ],
);

1;

