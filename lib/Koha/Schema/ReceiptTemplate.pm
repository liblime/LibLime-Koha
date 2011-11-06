package Koha::Schema::ReceiptTemplate;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'receipt_templates',

    columns => [
        module     => { type => 'varchar', default => '', length => 20, not_null => 1 },
        code       => { type => 'varchar', length => 20, not_null => 1 },
        branchcode => { type => 'varchar', length => 10, not_null => 1 },
        name       => { type => 'varchar', default => '', length => 100, not_null => 1 },
        content    => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'code', 'branchcode' ],
);

1;

