package Koha::MarcRecord;

use Moose::Role;
use MARC::Record;
use MARC::File::XML;
use Koha;

has 'marc' => (
    is => 'ro',
    isa => 'MARC::Record',
    lazy_build => 1,
    );

requires '_build_marc';

no Moose::Role;
1;
