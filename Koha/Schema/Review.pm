package Koha::Schema::Review;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'reviews',

    columns => [
        reviewid       => { type => 'serial', not_null => 1 },
        borrowernumber => { type => 'integer' },
        biblionumber   => { type => 'integer' },
        review         => { type => 'text', length => 65535 },
        approved       => { type => 'integer' },
        datereviewed   => { type => 'datetime' },
    ],

    primary_key_columns => [ 'reviewid' ],
);

1;

