package Koha::Schema::ItemCirculationAlertPreference;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'item_circulation_alert_preferences',

    columns => [
        id           => { type => 'serial', not_null => 1 },
        branchcode   => { type => 'varchar', length => 10, not_null => 1 },
        categorycode => { type => 'varchar', length => 10, not_null => 1 },
        item_type    => { type => 'varchar', length => 10, not_null => 1 },
        notification => { type => 'varchar', length => 16, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],
);

1;

