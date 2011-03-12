package C4::Schema::Item;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'items',

    columns => [
        barcode              => { type => 'varchar', length => 20 },
        biblioitemnumber     => { type => 'integer', default => '0', not_null => 1 },
        biblionumber         => { type => 'integer', default => '0', not_null => 1 },
        booksellerid         => { type => 'scalar', length => 16777215 },
        catstat              => { type => 'varchar', length => 80 },
        ccode                => { type => 'varchar', length => 10 },
        checkinnotes         => { type => 'varchar', length => 255 },
        cn_sort              => { type => 'varchar', length => 30 },
        cn_source            => { type => 'varchar', length => 10 },
        copynumber           => { type => 'varchar', length => 32 },
        damaged              => { type => 'integer', default => '0', not_null => 1 },
        dateaccessioned      => { type => 'date' },
        datelastborrowed     => { type => 'date' },
        datelastseen         => { type => 'date' },
        enumchron            => { type => 'varchar', length => 80 },
        holdingbranch        => { type => 'varchar', length => 10 },
        homebranch           => { type => 'varchar', length => 10 },
        issues               => { type => 'integer' },
        itemcallnumber       => { type => 'varchar', length => 255 },
        itemlost             => { type => 'integer', default => '0', not_null => 1 },
        itemnotes            => { type => 'scalar', length => 16777215 },
        itemnumber           => { type => 'serial', not_null => 1 },
        itype                => { type => 'varchar', length => 10 },
        location             => { type => 'varchar', length => 80 },
        materials            => { type => 'varchar', length => 10 },
        more_subfields_xml   => { type => 'scalar', length => 4294967295 },
        notforloan           => { type => 'integer', default => '0', not_null => 1 },
        onloan               => { type => 'date' },
        otherstatus          => { type => 'varchar', length => 10 },
        paidfor              => { type => 'scalar', length => 16777215 },
        permanent_location   => { type => 'varchar', length => 80 },
        price                => { type => 'numeric', precision => 8, scale => 2 },
        renewals             => { type => 'integer' },
        replacementprice     => { type => 'numeric', precision => 8, scale => 2 },
        replacementpricedate => { type => 'date' },
        reserves             => { type => 'integer' },
        restricted           => { type => 'integer' },
        stack                => { type => 'integer' },
        suppress             => { type => 'integer', default => '0', not_null => 1 },
        timestamp            => { type => 'timestamp', not_null => 1 },
        uri                  => { type => 'varchar', length => 255 },
        wthdrawn             => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'itemnumber' ],

    unique_key => [ 'barcode' ],

    foreign_keys => [
        biblioitem => {
            class       => 'C4::Schema::Biblioitem',
            key_columns => { biblioitemnumber => 'biblioitemnumber' },
        },
    ],

    relationships => [
        periodical_serials => {
            map_class => 'C4::Schema::SubscriptionSerial',
            map_from  => 'item',
            map_to    => 'periodical_serial',
            type      => 'many to many',
        },

        subscription_serials => {
            class      => 'C4::Schema::SubscriptionSerial',
            column_map => { itemnumber => 'itemnumber' },
            type       => 'one to many',
        },
    ],
);

1;

