package Koha::Schema::ClubsAndService;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'clubsAndServices',

    columns => [
        casId        => { type => 'serial', not_null => 1 },
        casaId       => { type => 'integer', default => '0', not_null => 1 },
        title        => { type => 'text', length => 65535, not_null => 1 },
        description  => { type => 'text', length => 65535 },
        casData1     => { type => 'text', length => 65535 },
        casData2     => { type => 'text', length => 65535 },
        casData3     => { type => 'text', length => 65535 },
        startDate    => { type => 'date', default => '0000-00-00', not_null => 1 },
        endDate      => { type => 'date' },
        branchcode   => { type => 'varchar', length => 4, not_null => 1 },
        last_updated => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'casId' ],
);

1;

