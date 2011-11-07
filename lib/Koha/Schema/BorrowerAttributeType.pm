package Koha::Schema::BorrowerAttributeType;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_attribute_types',

    columns => [
        code                      => { type => 'varchar', length => 10, not_null => 1 },
        description               => { type => 'varchar', length => 255, not_null => 1 },
        repeatable                => { type => 'integer', default => '0', not_null => 1 },
        unique_id                 => { type => 'integer', default => '0', not_null => 1 },
        opac_display              => { type => 'integer', default => '0', not_null => 1 },
        password_allowed          => { type => 'integer', default => '0', not_null => 1 },
        staff_searchable          => { type => 'integer', default => '0', not_null => 1 },
        authorised_value_category => { type => 'varchar', length => 10 },
    ],

    primary_key_columns => [ 'code' ],
);

1;

