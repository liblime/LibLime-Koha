package Koha::Schema::LabelsBatche;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'labels_batches',

    columns => [
        label_id    => { type => 'serial', not_null => 1 },
        batch_id    => { type => 'integer', default => 1, not_null => 1 },
        item_number => { type => 'integer', default => '0', not_null => 1 },
        timestamp   => { type => 'timestamp', not_null => 1 },
        branch_code => { type => 'varchar', default => 'NB', length => 10, not_null => 1 },
    ],

    primary_key_columns => [ 'label_id' ],

    foreign_keys => [
        item => {
            class       => 'Koha::Schema::Item',
            key_columns => { item_number => 'itemnumber' },
        },
    ],
);

1;

