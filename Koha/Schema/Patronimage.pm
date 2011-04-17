package Koha::Schema::Patronimage;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'patronimage',

    columns => [
        cardnumber => { type => 'varchar', length => 16, not_null => 1 },
        mimetype   => { type => 'varchar', length => 15, not_null => 1 },
        imagefile  => { type => 'scalar', length => 16777215, not_null => 1 },
    ],

    primary_key_columns => [ 'cardnumber' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { cardnumber => 'cardnumber' },
            rel_type    => 'one to one',
        },
    ],
);

1;

