package Koha::Schema::ClassSortRule;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'class_sort_rules',

    columns => [
        class_sort_rule => { type => 'varchar', length => 10, not_null => 1 },
        description     => { type => 'scalar', length => 16777215 },
        sort_routine    => { type => 'varchar', default => '', length => 30, not_null => 1 },
    ],

    primary_key_columns => [ 'class_sort_rule' ],
);

1;

