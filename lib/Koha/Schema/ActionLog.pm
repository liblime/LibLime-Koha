package Koha::Schema::ActionLog;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'action_logs',

    columns => [
        action_id => { type => 'serial', not_null => 1 },
        timestamp => { type => 'timestamp', not_null => 1 },
        user      => { type => 'integer', default => '0', not_null => 1 },
        module    => { type => 'text', length => 65535 },
        action    => { type => 'text', length => 65535 },
        object    => { type => 'integer' },
        info      => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'action_id' ],
);

1;

