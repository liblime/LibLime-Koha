package Koha::Schema::BiblioFramework;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'biblio_framework',

    columns => [
        frameworkcode => { type => 'varchar', length => 4, not_null => 1 },
        frameworktext => { type => 'varchar', default => '', length => 255, not_null => 1 },
    ],

    primary_key_columns => [ 'frameworkcode' ],
);

1;

