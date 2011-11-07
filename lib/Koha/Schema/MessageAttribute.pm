package Koha::Schema::MessageAttribute;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'message_attributes',

    columns => [
        message_attribute_id => { type => 'serial', not_null => 1 },
        message_name         => { type => 'varchar', default => '', length => 20, not_null => 1 },
        takes_days           => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'message_attribute_id' ],

    unique_key => [ 'message_name' ],

    relationships => [
        borrower_message_preferences => {
            class      => 'Koha::Schema::BorrowerMessagePreference',
            column_map => { message_attribute_id => 'message_attribute_id' },
            type       => 'one to many',
        },

        message_transports => {
            class      => 'Koha::Schema::MessageTransport',
            column_map => { message_attribute_id => 'message_attribute_id' },
            type       => 'one to many',
        },
    ],
);

1;

