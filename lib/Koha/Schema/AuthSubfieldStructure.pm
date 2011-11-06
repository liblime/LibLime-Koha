package Koha::Schema::AuthSubfieldStructure;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'auth_subfield_structure',

    columns => [
        authtypecode     => { type => 'varchar', length => 10, not_null => 1 },
        tagfield         => { type => 'varchar', length => 3, not_null => 1 },
        tagsubfield      => { type => 'varchar', length => 1, not_null => 1 },
        liblibrarian     => { type => 'varchar', default => '', length => 255, not_null => 1 },
        libopac          => { type => 'varchar', default => '', length => 255, not_null => 1 },
        repeatable       => { type => 'integer', default => '0', not_null => 1 },
        mandatory        => { type => 'integer', default => '0', not_null => 1 },
        tab              => { type => 'integer' },
        authorised_value => { type => 'varchar', length => 10 },
        value_builder    => { type => 'varchar', length => 80 },
        seealso          => { type => 'varchar', length => 255 },
        isurl            => { type => 'integer' },
        hidden           => { type => 'integer', default => '0', not_null => 1 },
        linkid           => { type => 'integer', default => '0', not_null => 1 },
        kohafield        => { type => 'varchar', default => '', length => 45 },
        frameworkcode    => { type => 'varchar', default => '', length => 8, not_null => 1 },
    ],

    primary_key_columns => [ 'authtypecode', 'tagfield', 'tagsubfield' ],
);

1;

