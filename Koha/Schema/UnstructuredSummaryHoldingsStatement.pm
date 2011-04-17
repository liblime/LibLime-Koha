package Koha::Schema::UnstructuredSummaryHoldingsStatement;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'unstructured_summary_holdings_statements',

    columns => [
        unstructured_summary_holdings_statement_id => { type => 'serial', not_null => 1 },
        summary_id                                 => { type => 'integer', default => '0' },
        sequence_number                            => { type => 'integer', default => '0', not_null => 1 },
        public_note                                => { type => 'character', default => '', length => 100 },
        staff_note                                 => { type => 'character', default => '', length => 100 },
        statement                                  => { type => 'scalar', length => 16777215, not_null => 1 },
    ],

    primary_key_columns => [ 'unstructured_summary_holdings_statement_id' ],

    foreign_keys => [
        summary => {
            class       => 'Koha::Schema::Summary',
            key_columns => { summary_id => 'summary_id' },
        },
    ],
);

1;

