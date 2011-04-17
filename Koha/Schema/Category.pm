package Koha::Schema::Category;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'categories',

    columns => [
        categorycode          => { type => 'varchar', length => 10, not_null => 1 },
        description           => { type => 'scalar', length => 16777215 },
        enrolmentperiod       => { type => 'integer' },
        upperagelimit         => { type => 'integer' },
        dateofbirthrequired   => { type => 'integer' },
        finetype              => { type => 'varchar', length => 30 },
        bulk                  => { type => 'integer' },
        enrolmentfee          => { type => 'numeric', precision => 28, scale => 6 },
        overduenoticerequired => { type => 'integer' },
        issuelimit            => { type => 'integer' },
        reservefee            => { type => 'numeric', precision => 28, scale => 6 },
        maxholds              => { type => 'integer' },
        holds_block_threshold => { type => 'numeric', precision => 28, scale => 6 },
        circ_block_threshold  => { type => 'numeric', precision => 28, scale => 6 },
        category_type         => { type => 'varchar', default => 'A', length => 1, not_null => 1 },
    ],

    primary_key_columns => [ 'categorycode' ],

    relationships => [
        borrower_message_preferences => {
            class      => 'Koha::Schema::BorrowerMessagePreference',
            column_map => { categorycode => 'categorycode' },
            type       => 'one to many',
        },

        borrowers => {
            class      => 'Koha::Schema::Borrower',
            column_map => { categorycode => 'categorycode' },
            type       => 'one to many',
        },

        circ_policieses => {
            map_class => 'Koha::Schema::CircRule',
            map_from  => 'category',
            map_to    => 'circ_policies',
            type      => 'many to many',
        },

        default_borrower_circ_rule => {
            class                => 'Koha::Schema::DefaultBorrowerCircRule',
            column_map           => { categorycode => 'categorycode' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },
    ],
);

1;

