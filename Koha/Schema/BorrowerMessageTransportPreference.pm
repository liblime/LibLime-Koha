package Koha::Schema::BorrowerMessageTransportPreference;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrower_message_transport_preferences',

    columns => [
        borrower_message_preference_id => { type => 'integer', not_null => 1 },
        message_transport_type         => { type => 'varchar', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'borrower_message_preference_id', 'message_transport_type' ],

    foreign_keys => [
        borrower_message_preference => {
            class       => 'Koha::Schema::BorrowerMessagePreference',
            key_columns => { borrower_message_preference_id => 'borrower_message_preference_id' },
        },

        message_transport_type_obj => {
            class       => 'Koha::Schema::MessageTransportType',
            key_columns => { message_transport_type => 'message_transport_type' },
        },
    ],
);

1;

