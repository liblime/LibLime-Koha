package Koha::Schema::Deletedbiblioitem;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'deletedbiblioitems',

    columns => [
        biblioitemnumber      => { type => 'integer', not_null => 1 },
        biblionumber          => { type => 'integer', default => '0', not_null => 1 },
        volume                => { type => 'scalar', length => 16777215 },
        number                => { type => 'scalar', length => 16777215 },
        itemtype              => { type => 'varchar', length => 10 },
        isbn                  => { type => 'varchar', length => 30 },
        issn                  => { type => 'varchar', length => 9 },
        publicationyear       => { type => 'text', length => 65535 },
        publishercode         => { type => 'varchar', length => 255 },
        volumedate            => { type => 'date' },
        volumedesc            => { type => 'text', length => 65535 },
        collectiontitle       => { type => 'scalar', length => 16777215 },
        collectionissn        => { type => 'text', length => 65535 },
        collectionvolume      => { type => 'scalar', length => 16777215 },
        editionstatement      => { type => 'text', length => 65535 },
        editionresponsibility => { type => 'text', length => 65535 },
        timestamp             => { type => 'timestamp', not_null => 1 },
        illus                 => { type => 'varchar', length => 255 },
        pages                 => { type => 'varchar', length => 255 },
        notes                 => { type => 'scalar', length => 16777215 },
        size                  => { type => 'varchar', length => 255 },
        place                 => { type => 'varchar', length => 255 },
        lccn                  => { type => 'varchar', length => 25 },
        marc                  => { type => 'scalar', length => 4294967295 },
        url                   => { type => 'varchar', length => 255 },
        cn_source             => { type => 'varchar', length => 10 },
        cn_class              => { type => 'varchar', length => 30 },
        cn_item               => { type => 'varchar', length => 10 },
        cn_suffix             => { type => 'varchar', length => 10 },
        cn_sort               => { type => 'varchar', length => 30 },
        totalissues           => { type => 'integer' },
        marcxml               => { type => 'scalar', length => 4294967295, not_null => 1 },
        on_order_count        => { type => 'varchar', length => 80 },
        in_process_count      => { type => 'varchar', length => 80 },
    ],

    primary_key_columns => [ 'biblioitemnumber' ],
);

1;

