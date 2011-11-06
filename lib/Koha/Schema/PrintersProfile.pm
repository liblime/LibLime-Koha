package Koha::Schema::PrintersProfile;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'printers_profile',

    columns => [
        profile_id   => { type => 'serial', not_null => 1 },
        printer_name => { type => 'varchar', default => 'Default Printer', length => 40, not_null => 1 },
        template_id  => { type => 'integer', default => '0', not_null => 1 },
        paper_bin    => { type => 'varchar', default => 'Bypass', length => 20, not_null => 1 },
        offset_horz  => { type => 'float', default => '0', not_null => 1, precision => 32 },
        offset_vert  => { type => 'float', default => '0', not_null => 1, precision => 32 },
        creep_horz   => { type => 'float', default => '0', not_null => 1, precision => 32 },
        creep_vert   => { type => 'float', default => '0', not_null => 1, precision => 32 },
        units        => { type => 'character', default => 'POINT', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'profile_id' ],

    unique_key => [ 'printer_name', 'template_id', 'paper_bin' ],
);

1;

