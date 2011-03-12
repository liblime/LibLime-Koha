package C4::Schema::Biblioitem;

use strict;

use base qw(C4::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'biblioitems',

    columns => [
        biblioitemnumber      => { type => 'serial', not_null => 1 },
        biblionumber          => { type => 'integer', default => '0', not_null => 1 },
        cn_class              => { type => 'varchar', length => 30 },
        cn_item               => { type => 'varchar', length => 10 },
        cn_sort               => { type => 'varchar', length => 30 },
        cn_source             => { type => 'varchar', length => 10 },
        cn_suffix             => { type => 'varchar', length => 10 },
        collectionissn        => { type => 'text', length => 65535 },
        collectiontitle       => { type => 'scalar', length => 16777215 },
        collectionvolume      => { type => 'scalar', length => 16777215 },
        editionresponsibility => { type => 'text', length => 65535 },
        editionstatement      => { type => 'text', length => 65535 },
        illus                 => { type => 'varchar', length => 255 },
        in_process_count      => { type => 'varchar', length => 80 },
        isbn                  => { type => 'varchar', length => 30 },
        issn                  => { type => 'varchar', length => 9 },
        itemtype              => { type => 'varchar', length => 10 },
        lccn                  => { type => 'varchar', length => 25 },
        marc                  => { type => 'scalar', length => 4294967295 },
        marcxml               => { type => 'scalar', length => 4294967295, not_null => 1 },
        notes                 => { type => 'scalar', length => 16777215 },
        number                => { type => 'scalar', length => 16777215 },
        on_order_count        => { type => 'varchar', length => 80 },
        pages                 => { type => 'varchar', length => 255 },
        place                 => { type => 'varchar', length => 255 },
        publicationyear       => { type => 'text', length => 65535 },
        publishercode         => { type => 'varchar', length => 255 },
        size                  => { type => 'varchar', length => 255 },
        timestamp             => { type => 'timestamp', not_null => 1 },
        totalissues           => { type => 'integer' },
        url                   => { type => 'varchar', length => 255 },
        volume                => { type => 'scalar', length => 16777215 },
        volumedate            => { type => 'date' },
        volumedesc            => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'biblioitemnumber' ],

    foreign_keys => [
        biblio => {
            class       => 'C4::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },
    ],

    relationships => [
        items => {
            class      => 'C4::Schema::Item',
            column_map => { biblioitemnumber => 'biblioitemnumber' },
            type       => 'one to many',
        },
    ],
);

1;

