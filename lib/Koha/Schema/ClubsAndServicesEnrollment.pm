package Koha::Schema::ClubsAndServicesEnrollment;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'clubsAndServicesEnrollments',

    columns => [
        caseId         => { type => 'serial', not_null => 1 },
        casaId         => { type => 'integer', default => '0', not_null => 1 },
        casId          => { type => 'integer', default => '0', not_null => 1 },
        borrowernumber => { type => 'integer', default => '0', not_null => 1 },
        data1          => { type => 'text', length => 65535 },
        data2          => { type => 'text', length => 65535 },
        data3          => { type => 'text', length => 65535 },
        dateEnrolled   => { type => 'date', default => '0000-00-00', not_null => 1 },
        dateCanceled   => { type => 'date' },
        last_updated   => { type => 'timestamp', not_null => 1 },
        branchcode     => { type => 'varchar', length => 4 },
    ],

    primary_key_columns => [ 'caseId' ],
);

1;

