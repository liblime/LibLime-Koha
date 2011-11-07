package Koha::Schema::BorrowerMessagePreference;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_message_preferences',

    columns => [
        borrower_message_preference_id => { type => 'serial', not_null => 1 },
        borrowernumber                 => { type => 'integer' },
        categorycode                   => { type => 'varchar', length => 10 },
        message_attribute_id           => { type => 'integer', default => '0' },
        days_in_advance                => { type => 'integer', default => '0' },
        wants_digest                   => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'borrower_message_preference_id' ],

    foreign_keys => [
        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        category => {
            class       => 'Koha::Schema::Category',
            key_columns => { categorycode => 'categorycode' },
        },

        message_attribute => {
            class       => 'Koha::Schema::MessageAttribute',
            key_columns => { message_attribute_id => 'message_attribute_id' },
        },
    ],

    relationships => [
        message_transport_type_objs => {
            map_class => 'Koha::Schema::BorrowerMessageTransportPreference',
            map_from  => 'borrower_message_preference',
            map_to    => 'message_transport_type_obj',
            type      => 'many to many',
        },
    ],
);

1;

