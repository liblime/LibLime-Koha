#!/usr/bin/perl
#
use strict;
use warnings;

use Test::More tests => 8;                      # last test to print

BEGIN {
    use_ok('C4::ItemDeleteList');
}

can_ok('C4::ItemDeleteList',qw(new append list_id item_barcodes remove_all rowcount remove));

my $idl = C4::ItemDeleteList->new;
ok( defined $idl );
ok( $idl->isa('C4::ItemDeleteList'));
my $idl2 = C4::ItemDeleteList->new;
cmp_ok($idl2->list_id(), '!=', $idl->list_id(), 'list ids are unique');

is($idl->rowcount(), 0, 'Empty list returns correct length');
$idl->append({itemnumber => 1, biblionumber => 2});
is($idl->rowcount(), 1, 'List size grows after append');
$idl->remove( 1 );
is($idl->rowcount(), 0, 'remove_item removes row');



