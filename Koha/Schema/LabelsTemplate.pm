package Koha::Schema::LabelsTemplate;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'labels_templates',

    columns => [
        template_id      => { type => 'serial', not_null => 1 },
        profile_id       => { type => 'integer' },
        template_code    => { type => 'character', default => 'DEFAULT TEMPLATE', length => 100, not_null => 1 },
        template_desc    => { type => 'character', default => 'Default description', length => 100, not_null => 1 },
        page_width       => { type => 'float', default => '0', not_null => 1, precision => 32 },
        page_height      => { type => 'float', default => '0', not_null => 1, precision => 32 },
        label_width      => { type => 'float', default => '0', not_null => 1, precision => 32 },
        label_height     => { type => 'float', default => '0', not_null => 1, precision => 32 },
        top_text_margin  => { type => 'float', default => '0', not_null => 1, precision => 32 },
        left_text_margin => { type => 'float', default => '0', not_null => 1, precision => 32 },
        top_margin       => { type => 'float', default => '0', not_null => 1, precision => 32 },
        left_margin      => { type => 'float', default => '0', not_null => 1, precision => 32 },
        cols             => { type => 'integer', default => '0', not_null => 1 },
        rows             => { type => 'integer', default => '0', not_null => 1 },
        col_gap          => { type => 'float', default => '0', not_null => 1, precision => 32 },
        row_gap          => { type => 'float', default => '0', not_null => 1, precision => 32 },
        units            => { type => 'character', default => 'POINT', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'template_id' ],
);

1;

