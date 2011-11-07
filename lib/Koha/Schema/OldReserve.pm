package Koha::Schema::OldReserve;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'old_reserves',

    columns => [
        reservenumber    => { type => 'integer', not_null => 1 },
        borrowernumber   => { type => 'integer' },
        reservedate      => { type => 'datetime' },
        biblionumber     => { type => 'integer' },
        constrainttype   => { type => 'varchar', length => 1 },
        branchcode       => { type => 'varchar', length => 10 },
        notificationdate => { type => 'date' },
        reminderdate     => { type => 'date' },
        cancellationdate => { type => 'date' },
        reservenotes     => { type => 'scalar', length => 16777215 },
        priority         => { type => 'integer' },
        found            => { type => 'varchar', length => 1 },
        timestamp        => { type => 'timestamp', not_null => 1 },
        itemnumber       => { type => 'integer' },
        waitingdate      => { type => 'date' },
        expirationdate   => { type => 'date' },
        displayexpired   => { type => 'integer', default => 1, not_null => 1 },
    ],

    primary_key_columns => [ 'reservenumber' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },
    ],
);

1;

