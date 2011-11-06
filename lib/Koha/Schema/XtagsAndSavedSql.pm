package Koha::Schema::XtagsAndSavedSql;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'xtags_and_saved_sql',

    columns => [
        id           => { type => 'serial', not_null => 1 },
        xtag_id      => { type => 'integer', not_null => 1 },
        saved_sql_id => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'xtag_id', 'saved_sql_id' ],
);

1;

