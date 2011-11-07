package Koha::Schema::ClubsAndServicesArchetype;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'clubsAndServicesArchetypes',

    columns => [
        casaId           => { type => 'serial', not_null => 1 },
        type             => { type => 'enum', check_in => [ 'club', 'service' ], default => 'club', not_null => 1 },
        title            => { type => 'text', length => 65535, not_null => 1 },
        description      => { type => 'text', length => 65535, not_null => 1 },
        publicEnrollment => { type => 'integer', default => '0', not_null => 1 },
        casData1Title    => { type => 'text', length => 65535 },
        casData2Title    => { type => 'text', length => 65535 },
        casData3Title    => { type => 'text', length => 65535 },
        caseData1Title   => { type => 'text', length => 65535 },
        caseData2Title   => { type => 'text', length => 65535 },
        caseData3Title   => { type => 'text', length => 65535 },
        casData1Desc     => { type => 'text', length => 65535 },
        casData2Desc     => { type => 'text', length => 65535 },
        casData3Desc     => { type => 'text', length => 65535 },
        caseData1Desc    => { type => 'text', length => 65535 },
        caseData2Desc    => { type => 'text', length => 65535 },
        caseData3Desc    => { type => 'text', length => 65535 },
        caseRequireEmail => { type => 'integer', default => '0', not_null => 1 },
        branchcode       => { type => 'varchar', length => 4 },
        last_updated     => { type => 'timestamp', not_null => 1 },
    ],

    primary_key_columns => [ 'casaId' ],
);

1;

