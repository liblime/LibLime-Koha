package Koha::Schema::Aqorder;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'aqorders',

    columns => [
        ordernumber             => { type => 'serial', not_null => 1 },
        biblionumber            => { type => 'integer' },
        title                   => { type => 'scalar', length => 16777215 },
        entrydate               => { type => 'date' },
        quantity                => { type => 'integer' },
        currency                => { type => 'varchar', length => 3 },
        listprice               => { type => 'numeric', precision => 28, scale => 6 },
        totalamount             => { type => 'numeric', precision => 28, scale => 6 },
        datereceived            => { type => 'date' },
        booksellerinvoicenumber => { type => 'scalar', length => 16777215 },
        freight                 => { type => 'numeric', precision => 28, scale => 6 },
        unitprice               => { type => 'numeric', precision => 28, scale => 6 },
        quantityreceived        => { type => 'integer' },
        cancelledby             => { type => 'varchar', length => 10 },
        datecancellationprinted => { type => 'date' },
        notes                   => { type => 'scalar', length => 16777215 },
        supplierreference       => { type => 'scalar', length => 16777215 },
        purchaseordernumber     => { type => 'scalar', length => 16777215 },
        subscription            => { type => 'integer' },
        serialid                => { type => 'varchar', length => 30 },
        basketno                => { type => 'integer' },
        biblioitemnumber        => { type => 'integer' },
        timestamp               => { type => 'timestamp', not_null => 1 },
        rrp                     => { type => 'numeric', precision => 13, scale => 2 },
        ecost                   => { type => 'numeric', precision => 13, scale => 2 },
        gst                     => { type => 'numeric', precision => 13, scale => 2 },
        budgetdate              => { type => 'date' },
        sort1                   => { type => 'varchar', length => 80 },
        sort2                   => { type => 'varchar', length => 80 },
    ],

    primary_key_columns => [ 'ordernumber' ],

    foreign_keys => [
        aqbasket => {
            class       => 'Koha::Schema::Aqbasket',
            key_columns => { basketno => 'basketno' },
        },

        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },
    ],
);

1;

