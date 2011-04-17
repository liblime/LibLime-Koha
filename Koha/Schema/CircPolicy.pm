package Koha::Schema::CircPolicy;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'circ_policies',

    columns => [
        id                => { type => 'serial', not_null => 1 },
        description       => { type => 'varchar', length => 80, not_null => 1 },
        branchcode        => { type => 'varchar', length => 10 },
        rentalcharge      => { type => 'numeric', precision => 28, scale => 6 },
        replacement_fee   => { type => 'numeric', precision => 28, scale => 6 },
        overdue_fine      => { type => 'numeric', precision => 28, scale => 6 },
        issue_length      => { type => 'integer', not_null => 1 },
        issue_length_unit => { type => 'enum', check_in => [ 'days', 'hours', 'minutes' ], default => 'days', not_null => 1 },
        grace_period      => { type => 'integer', not_null => 1 },
        grace_period_unit => { type => 'enum', check_in => [ 'days', 'hours', 'minutes' ], default => 'days', not_null => 1 },
        fine_period       => { type => 'integer', not_null => 1 },
        fine_period_unit  => { type => 'enum', check_in => [ 'days', 'hours', 'minutes' ], default => 'days', not_null => 1 },
        loan_type         => { type => 'enum', check_in => [ 'daily', 'hourly' ], default => 'daily', not_null => 1 },
        maxissueqty       => { type => 'integer' },
        maxrenewals       => { type => 'integer' },
        maxfine           => { type => 'numeric', precision => 28, scale => 6 },
        hourly_incr       => { type => 'integer' },
        allow_overnight   => { type => 'integer' },
        allow_over_closed => { type => 'integer' },
        overnight_due     => { type => 'integer' },
        overnight_window  => { type => 'integer' },
        allow_callslip    => { type => 'integer' },
        allow_doc_del     => { type => 'integer' },
    ],

    primary_key_columns => [ 'id' ],

    relationships => [
        categories => {
            map_class => 'Koha::Schema::CircRule',
            map_from  => 'circ_policies',
            map_to    => 'category',
            type      => 'many to many',
        },
    ],
);

1;

