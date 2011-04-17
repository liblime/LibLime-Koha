package Koha::Schema::Aqbudget;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'aqbudget',

    columns => [
        bookfundid   => { type => 'varchar', default => '', length => 10, not_null => 1 },
        startdate    => { type => 'date', default => '0000-00-00', not_null => 1 },
        enddate      => { type => 'date' },
        budgetamount => { type => 'numeric', precision => 13, scale => 2 },
        aqbudgetid   => { type => 'serial', not_null => 1 },
        branchcode   => { type => 'varchar', length => 10 },
    ],

    primary_key_columns => [ 'aqbudgetid' ],
);

1;

