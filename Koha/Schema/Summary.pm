package Koha::Schema::Summary;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'summaries',

    columns => [
        summary_id              => { type => 'serial', not_null => 1 },
        biblionumber            => { type => 'integer' },
        homebranch              => { type => 'varchar', length => 10 },
        holdingbranch           => { type => 'varchar', length => 10 },
        callnumber              => { type => 'character', default => '', length => 30 },
        shelvinglocation        => { type => 'integer' },
        call_number_source      => { type => 'character', default => '', length => 10 },
        collection_code         => { type => 'integer' },
        URI                     => { type => 'character', default => '', length => 255 },
        itemtype                => { type => 'varchar', length => 10 },
        copy_number             => { type => 'integer', default => '0' },
        last_modified_by        => { type => 'integer', default => '0' },
        last_modified_timestamp => { type => 'timestamp', not_null => 1 },
        created_by              => { type => 'integer', default => '0' },
        created_timestamp       => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'summary_id' ],

    foreign_keys => [
        authorised_value => {
            class       => 'Koha::Schema::AuthorisedValue',
            key_columns => { collection_code => 'id' },
        },

        authorised_value_obj => {
            class       => 'Koha::Schema::AuthorisedValue',
            key_columns => { shelvinglocation => 'id' },
        },

        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { created_by => 'borrowernumber' },
        },

        borrower_obj => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { last_modified_by => 'borrowernumber' },
        },

        itemtype_obj => {
            class       => 'Koha::Schema::Itemtype',
            key_columns => { itemtype => 'itemtype' },
        },
    ],

    relationships => [
        structured_summary_holdings_statements => {
            class      => 'Koha::Schema::StructuredSummaryHoldingsStatement',
            column_map => { summary_id => 'summary_id' },
            type       => 'one to many',
        },

        unstructured_summary_holdings_statements => {
            class      => 'Koha::Schema::UnstructuredSummaryHoldingsStatement',
            column_map => { summary_id => 'summary_id' },
            type       => 'one to many',
        },
    ],
);

1;

