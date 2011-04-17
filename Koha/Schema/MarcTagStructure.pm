package Koha::Schema::MarcTagStructure;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'marc_tag_structure',

    columns => [
        tagfield         => { type => 'varchar', length => 3, not_null => 1 },
        liblibrarian     => { type => 'varchar', default => '', length => 255, not_null => 1 },
        libopac          => { type => 'varchar', default => '', length => 255, not_null => 1 },
        repeatable       => { type => 'integer', default => '0', not_null => 1 },
        mandatory        => { type => 'integer', default => '0', not_null => 1 },
        authorised_value => { type => 'varchar', length => 10 },
        frameworkcode    => { type => 'varchar', length => 4, not_null => 1 },
    ],

    primary_key_columns => [ 'frameworkcode', 'tagfield' ],
);

1;

