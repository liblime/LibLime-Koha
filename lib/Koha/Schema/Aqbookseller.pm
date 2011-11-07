package Koha::Schema::Aqbookseller;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'aqbooksellers',

    columns => [
        id              => { type => 'serial', not_null => 1 },
        name            => { type => 'scalar', length => 16777215, not_null => 1 },
        address1        => { type => 'scalar', length => 16777215 },
        address2        => { type => 'scalar', length => 16777215 },
        address3        => { type => 'scalar', length => 16777215 },
        address4        => { type => 'scalar', length => 16777215 },
        phone           => { type => 'varchar', length => 30 },
        accountnumber   => { type => 'scalar', length => 16777215 },
        othersupplier   => { type => 'scalar', length => 16777215 },
        currency        => { type => 'varchar', default => '', length => 3, not_null => 1 },
        deliverydays    => { type => 'integer' },
        followupdays    => { type => 'integer' },
        followupscancel => { type => 'integer' },
        specialty       => { type => 'scalar', length => 16777215 },
        booksellerfax   => { type => 'scalar', length => 16777215 },
        notes           => { type => 'scalar', length => 16777215 },
        bookselleremail => { type => 'scalar', length => 16777215 },
        booksellerurl   => { type => 'scalar', length => 16777215 },
        contact         => { type => 'varchar', length => 100 },
        postal          => { type => 'scalar', length => 16777215 },
        url             => { type => 'varchar', length => 255 },
        contpos         => { type => 'varchar', length => 100 },
        contphone       => { type => 'varchar', length => 100 },
        contfax         => { type => 'varchar', length => 100 },
        contaltphone    => { type => 'varchar', length => 100 },
        contemail       => { type => 'varchar', length => 100 },
        contnotes       => { type => 'scalar', length => 16777215 },
        active          => { type => 'integer' },
        listprice       => { type => 'varchar', length => 10 },
        invoiceprice    => { type => 'varchar', length => 10 },
        gstreg          => { type => 'integer' },
        listincgst      => { type => 'integer' },
        invoiceincgst   => { type => 'integer' },
        discount        => { type => 'float', precision => 32 },
        fax             => { type => 'varchar', length => 50 },
        nocalc          => { type => 'integer' },
        invoicedisc     => { type => 'float', precision => 32 },
    ],

    primary_key_columns => [ 'id' ],

    foreign_keys => [
        currency_obj => {
            class       => 'Koha::Schema::Currency',
            key_columns => { listprice => 'currency' },
        },

        currency_object => {
            class       => 'Koha::Schema::Currency',
            key_columns => { invoiceprice => 'currency' },
        },
    ],

    relationships => [
        aqbasket => {
            class      => 'Koha::Schema::Aqbasket',
            column_map => { id => 'booksellerid' },
            type       => 'one to many',
        },

        subscriptions => {
            class      => 'Koha::Schema::Subscription',
            column_map => { id => 'aqbookseller_id' },
            type       => 'one to many',
        },
    ],
);

1;

