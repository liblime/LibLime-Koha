#!/usr/bin/env perl

use Koha;
use Test::More tests => 6;

BEGIN {
    use_ok('Koha::Model::Reserve');
    use_ok('Koha::Model::ReserveSet');
}

isa_ok (Koha::Model::Reserve->new(), 'Koha::Model::Reserve');

my $rdb = Koha::Schema::Reserve->new(
    biblionumber => 1234,
    borrowernumber => 2345,
    branchcode => 'ASDF',
    reservedate => DateTime->now,
    );
my $r = Koha::Model::Reserve->new(db_obj => $rdb);
isa_ok ($r, 'Koha::Model::Reserve', 'can acquire db_obj at new()');
is $r->borrowernumber, 2345, 'can acquire db_obj attributes';

my $rs = Koha::Model::ReserveSet->new(limits => {biblionumber => 1});
isa_ok ($rs, 'Koha::Model::ReserveSet', 'Can generate ReserveSet');
