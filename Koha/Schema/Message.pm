package Koha::Schema::Message;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'messages',

    columns => [
        message_id       => { type => 'serial', not_null => 1 },
        borrowernumber   => { type => 'integer', not_null => 1 },
        branchcode       => { type => 'varchar', length => 4 },
        message_type     => { type => 'varchar', length => 1, not_null => 1 },
        message          => { type => 'text', length => 65535, not_null => 1 },
        message_date     => { type => 'timestamp', not_null => 1 },
        checkout_display => { type => 'integer', default => 1, not_null => 1 },
        auth_value       => { type => 'varchar', length => 80 },
        staffnumber      => { type => 'integer', not_null => 1 },
    ],

    primary_key_columns => [ 'message_id' ],
);

1;

