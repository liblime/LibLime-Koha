package Koha::Schema::SummaryRecordTemplate;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'summary_record_templates',

    columns => [
        id                 => { type => 'serial', not_null => 1 },
        homebranch         => { type => 'varchar', default => '', length => 10, not_null => 1 },
        holdingbranch      => { type => 'varchar', default => '', length => 10, not_null => 1 },
        itemtype           => { type => 'varchar', default => '', length => 10, not_null => 1 },
        shelvinglocation   => { type => 'character', default => '', length => 80, not_null => 1 },
        call_number_source => { type => 'character', default => '', length => 10, not_null => 1 },
        collection_code    => { type => 'character', default => '', length => 10, not_null => 1 },
        URI                => { type => 'character', default => '', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        itemtype_obj => {
            class       => 'Koha::Schema::Itemtype',
            key_columns => { itemtype => 'itemtype' },
        },
    ],
);

1;

