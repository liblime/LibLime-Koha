package Koha::Schema::MessageTransport;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'message_transports',

    columns => [
        message_attribute_id   => { type => 'integer', not_null => 1 },
        message_transport_type => { type => 'varchar', length => 20, not_null => 1 },
        is_digest              => { type => 'integer', not_null => 1 },
        letter_module          => { type => 'varchar', default => '', length => 20, not_null => 1 },
        letter_code            => { type => 'varchar', default => '', length => 20, not_null => 1 },
    ],

    primary_key_columns => [ 'message_attribute_id', 'message_transport_type', 'is_digest' ],

    foreign_keys => [
        letter => {
            class       => 'Koha::Schema::Letter',
            key_columns => {
                letter_code   => 'code',
                letter_module => 'module',
            },
        },

        message_attribute => {
            class       => 'Koha::Schema::MessageAttribute',
            key_columns => { message_attribute_id => 'message_attribute_id' },
        },

        message_transport_type_obj => {
            class       => 'Koha::Schema::MessageTransportType',
            key_columns => { message_transport_type => 'message_transport_type' },
        },
    ],
);

1;

