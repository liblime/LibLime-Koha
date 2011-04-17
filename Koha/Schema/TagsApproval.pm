package Koha::Schema::TagsApproval;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'tags_approval',

    columns => [
        term          => { type => 'varchar', length => 255, not_null => 1 },
        approved      => { type => 'integer', default => '0', not_null => 1 },
        date_approved => { type => 'datetime' },
        approved_by   => { type => 'integer' },
        weight_total  => { type => 'integer', default => 1, not_null => 1 },
    ],

    primary_key_columns => [ 'term' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { approved_by => 'borrowernumber' },
        },
    ],

    relationships => [
        tags_index => {
            class      => 'Koha::Schema::TagsIndex',
            column_map => { term => 'term' },
            type       => 'one to many',
        },
    ],
);

1;

