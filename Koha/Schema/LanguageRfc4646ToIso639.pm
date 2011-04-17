package Koha::Schema::LanguageRfc4646ToIso639;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'language_rfc4646_to_iso639',

    columns => [
        rfc4646_subtag => { type => 'varchar', length => 25 },
        iso639_2_code  => { type => 'varchar', length => 25 },
        id             => { type => 'serial', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

