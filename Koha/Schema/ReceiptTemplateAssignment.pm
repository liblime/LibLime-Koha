package Koha::Schema::ReceiptTemplateAssignment;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'receipt_template_assignments',

    columns => [
        action     => { type => 'varchar', length => 30, not_null => 1 },
        branchcode => { type => 'varchar', length => 10, not_null => 1 },
        code       => { type => 'varchar', length => 20 },
    ],

    primary_key_columns => [ 'action', 'branchcode' ],
);

1;

