#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 27;
use DateTime;

sub run_testpad {
    use Data::Dumper;
    my ($func, $label, $testpad) = @_;
    for my $test (@$testpad) {
        ok($func->(@{$test->{args}}) eq $test->{result}, $label);
    }    
}

BEGIN {
    use_ok('C4::Control::PeriodicalSerialFormats');
}

my @testpad;

@testpad = (
    {args => ['1,1,9999:1,1,12:0,0,0', '1:1:0'],  result => '1:2:0'},
    {args => ['1,1,9999:1,1,12:0,0,0', '1:12:0'], result => '2:1:0'},
    {args => ['1,1,9999:1,1,12:1,1,4', '1:11:3'], result => '1:11:4'},
    {args => ['1,1,9999:1,1,12:1,1,4', '1:12:4'], result => '2:1:1'},
    {args => ['1,1,9999:1,1,12:1,2,4', '1:1:3'],  result => '1:2:1'},
    {args => ['1,1,9999:1,1,12:2,2,4', '1:1:4'],  result => '1:2:2'},
    );
run_testpad(\&C4::Control::PeriodicalSerialFormats::PredictNextSequenceFromSeed, 'PredictNextSequenceFromSeed', \@testpad);

my $date = DateTime->new(year => 2010, month => 01, day => 01);
@testpad = (
    {args => ['1d', $date],   result => '2010-01-02T00:00:00'},
    {args => ['2d', $date],   result => '2010-01-03T00:00:00'},
    {args => ['1w', $date],   result => '2010-01-08T00:00:00'},
    {args => ['2w', $date],   result => '2010-01-15T00:00:00'},
    {args => ['1/4y', $date], result => '2010-04-01T00:00:00'},
    {args => ['1y', $date],   result => '2011-01-01T00:00:00'},
    {args => ['2y', $date],   result => '2012-01-01T00:00:00'},
    );
run_testpad(\&C4::Control::PeriodicalSerialFormats::PredictNextChronologyFromSeed, 'PredictNextChronologyFromSeed', \@testpad);


ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn} {Zn}',   '1:12:4', '2010') eq '1 12 4',    'FormatSequence 1');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys}',        '1:3:0',  '2010') eq '2010 Summer', 'FormatSequence 2');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn+1}',      '1:12:0', '2010') eq '1 12/13',    'FormatSequence 3');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn} {Zn+2}', '1:12:1', '2010') eq '1 12 1/2/3',    'FormatSequence 4');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys+1}',      '1:3:0',  '2010') eq '2010 Summer/Fall', 'FormatSequence 5');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys+2}',      '1:3:0',  '2010') eq '2010 Summer/Fall/Winter', 'FormatSequence 6');
ok(C4::Control::PeriodicalSerialFormats::FormatSequence('Vol. {Xn} Issue {Yn} No. {Zn}', '1:12:4', '2010') eq 'Vol. 1 Issue 12 No. 4', 'FormatSequence 7');

ok(C4::Control::PeriodicalSerialFormats::FormatChronology('%Y-%m-%d', $date) eq '2010-01-01', 'FormatChronology 1');
ok(C4::Control::PeriodicalSerialFormats::FormatChronology('%q %Y', $date) eq 'Winter 2010', 'FormatChronology 2');
ok(C4::Control::PeriodicalSerialFormats::FormatChronology('%Q %Y', $date) eq 'Summer 2010', 'FormatChronology 3');

ok(C4::Control::PeriodicalSerialFormats::FormatVintage('Vol. 1', '2010-01-01') eq 'Vol. 1 : 2010-01-01', 'FormatVintage 1');
ok(C4::Control::PeriodicalSerialFormats::FormatVintage(undef, '2010-01-01')    eq '2010-01-01',          'FormatVintage 2');
ok(C4::Control::PeriodicalSerialFormats::FormatVintage('Vol. 1', undef)        eq 'Vol. 1',              'FormatVintage 3');

exit 0;
