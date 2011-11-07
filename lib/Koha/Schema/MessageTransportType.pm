package Koha::Schema::MessageTransportType;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'message_transport_types',

    columns => [
        message_transport_type => { type => 'varchar', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'message_transport_type' ],

    relationships => [
        borrower_message_preferences => {
            map_class => 'Koha::Schema::BorrowerMessageTransportPreference',
            map_from  => 'message_transport_type_obj',
            map_to    => 'borrower_message_preference',
            type      => 'many to many',
        },

        message_transports => {
            class      => 'Koha::Schema::MessageTransport',
            column_map => { message_transport_type => 'message_transport_type' },
            type       => 'one to many',
        },
    ],
);

1;

