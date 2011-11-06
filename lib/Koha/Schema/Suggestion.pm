package Koha::Schema::Suggestion;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'suggestions',

    columns => [
        suggestionid    => { type => 'serial', not_null => 1 },
        suggestedby     => { type => 'integer', default => '0', not_null => 1 },
        managedby       => { type => 'integer' },
        STATUS          => { type => 'varchar', default => '', length => 10, not_null => 1 },
        note            => { type => 'scalar', length => 16777215 },
        author          => { type => 'varchar', length => 80 },
        title           => { type => 'varchar', length => 80 },
        copyrightdate   => { type => 'integer' },
        publishercode   => { type => 'varchar', length => 255 },
        date            => { type => 'timestamp', not_null => 1 },
        volumedesc      => { type => 'varchar', length => 255 },
        publicationyear => { type => 'integer', default => '0' },
        place           => { type => 'varchar', length => 255 },
        isbn            => { type => 'varchar', length => 30 },
        mailoverseeing  => { type => 'integer', default => '0' },
        biblionumber    => { type => 'integer' },
        reason          => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'suggestionid' ],
);

1;

