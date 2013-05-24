#!/usr/bin/env perl

use Koha;
use utf8;
use Test::More;
use MARC::Field;
use MARC::Record;
use MARC::Field::Normalize::NACO qw(
    naco_from_string naco_from_array
    naco_from_field naco_from_authority
);

my @string_tests = (
    [ 'asdf', 'ASDF' ],
    [ 'Fouts, Clay', 'FOUTS, CLAY' ],
    [ 'Fouts, Clay, 1974-', 'FOUTS, CLAY 1974' ],
    ['ümðølæt H₂0 [hocus ©ocuß]', 'UMDOLAET H20 HOCUS OCUSS'],
    ['   random     WHITE space    ', 'RANDOM WHITE SPACE'],
    ['   random|    WHITE space    ', 'RANDOM WHITE SPACE'],
);

for (@string_tests) {
    is naco_from_string($_->[0], keep_first_comma => 1), $_->[1];
}

my @array_tests = (
    [
        [ 'a', 'Fouts, Clay', 'd', '1974-'],
        '$aFOUTS, CLAY$d1974'
    ],
    [
        [ 'a', 'Fouts, Clay', 'd', '1974-', 'n', 'lots, of, commas,'],
        '$aFOUTS, CLAY$d1974$nLOTS OF COMMAS'
    ],
    [
        [ 'a', 'Fouts, Clay', '2', 'fast', 'd', '1974-', '0', '(ZXC)1234', 'w', 'drop me'],
        '$aFOUTS, CLAY$2FAST$d1974$0ZXC 1234$wDROP ME'
    ],
);

for (@array_tests) {
    is naco_from_array($_->[0]), $_->[1];
}

pop @array_tests;
push @array_tests,
    [
        [ 'a', 'Fouts, Clay', '2', 'fast', 'd', '1974-', '0', '(ZXC)1234', 'w', 'drop me'],
        '$aFOUTS, CLAY$d1974'
    ];

my @field_tests = map {
    [ MARC::Field->new('100', ' ', ' ', @{$_->[0]}), $_->[1] ]
} @array_tests;

for (@field_tests) {
    is naco_from_field($_->[0], subfields => 'adn'), $_->[1];
    is $_->[0]->as_naco(subfields => 'adn'), $_->[1];
}

pop @field_tests;
for (@field_tests) {
    my $r = MARC::Record->new;
    $r->append_fields($_->[0]);
    is naco_from_authority($r), $_->[1];
}

done_testing;
