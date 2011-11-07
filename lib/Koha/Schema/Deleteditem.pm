package Koha::Schema::Deleteditem;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'deleteditems',

    columns => [
        itemnumber           => { type => 'integer', not_null => 1 },
        biblionumber         => { type => 'integer', default => '0', not_null => 1 },
        biblioitemnumber     => { type => 'integer', default => '0', not_null => 1 },
        barcode              => { type => 'varchar', length => 20 },
        dateaccessioned      => { type => 'date' },
        booksellerid         => { type => 'scalar', length => 16777215 },
        homebranch           => { type => 'varchar', length => 10 },
        price                => { type => 'numeric', precision => 8, scale => 2 },
        replacementprice     => { type => 'numeric', precision => 8, scale => 2 },
        replacementpricedate => { type => 'date' },
        datelastborrowed     => { type => 'date' },
        datelastseen         => { type => 'date' },
        stack                => { type => 'integer' },
        notforloan           => { type => 'integer', default => '0', not_null => 1 },
        damaged              => { type => 'integer', default => '0', not_null => 1 },
        itemlost             => { type => 'integer', default => '0', not_null => 1 },
        wthdrawn             => { type => 'integer', default => '0', not_null => 1 },
        suppress             => { type => 'integer', default => '0', not_null => 1 },
        itemcallnumber       => { type => 'varchar', length => 255 },
        issues               => { type => 'integer' },
        renewals             => { type => 'integer' },
        reserves             => { type => 'integer' },
        restricted           => { type => 'integer' },
        itemnotes            => { type => 'scalar', length => 16777215 },
        checkinnotes         => { type => 'varchar', length => 255 },
        holdingbranch        => { type => 'varchar', length => 10 },
        paidfor              => { type => 'scalar', length => 16777215 },
        timestamp            => { type => 'timestamp', not_null => 1 },
        location             => { type => 'varchar', length => 80 },
        permanent_location   => { type => 'varchar', length => 80 },
        onloan               => { type => 'date' },
        cn_source            => { type => 'varchar', length => 10 },
        cn_sort              => { type => 'varchar', length => 30 },
        ccode                => { type => 'varchar', length => 10 },
        materials            => { type => 'varchar', length => 10 },
        uri                  => { type => 'varchar', length => 255 },
        itype                => { type => 'varchar', length => 10 },
        more_subfields_xml   => { type => 'scalar', length => 4294967295 },
        enumchron            => { type => 'varchar', length => 80 },
        copynumber           => { type => 'varchar', length => 32 },
        marc                 => { type => 'scalar', length => 4294967295 },
        otherstatus          => { type => 'varchar', length => 10 },
        catstat              => { type => 'varchar', length => 80 },
    ],

    primary_key_columns => [ 'itemnumber' ],
);

1;

