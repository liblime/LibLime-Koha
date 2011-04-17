package Koha::Schema::LabelsLayout;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'labels_layouts',

    columns => [
        layout_id         => { type => 'serial', not_null => 1 },
        barcode_type      => { type => 'character', default => 'CODE39', length => 100, not_null => 1 },
        printing_type     => { type => 'character', default => 'BAR', length => 32, not_null => 1 },
        layout_name       => { type => 'character', default => 'DEFAULT', length => 20, not_null => 1 },
        guidebox          => { type => 'integer', default => '0' },
        font              => { type => 'character', default => 'TR', length => 10, not_null => 1 },
        font_size         => { type => 'integer', default => 10, not_null => 1 },
        callnum_split     => { type => 'varchar', length => 8 },
        text_justify      => { type => 'character', default => 'L', length => 1, not_null => 1 },
        format_string     => { type => 'varchar', default => 'barcode', length => 210, not_null => 1 },
        break_rule_string => { type => 'varchar', default => '', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'layout_id' ],
);

1;

