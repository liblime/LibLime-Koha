#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 32;
use DateTime;

BEGIN {
    use_ok('C4::Control::Periodical');
    use_ok('C4::Control::PeriodicalSerial');
    use_ok('C4::Control::Subscription');
    use_ok('C4::View::Serials');

    my $template = HTML::Template->new(filename => '/dev/null', die_on_bad_params => 0);

    isa_ok(C4::View::Serials::SeedTemplateWithGeneralData($template),                            'HTML::Template');
    isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalData($template, 1),                      'HTML::Template');
    isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, issn => '1234'),       'HTML::Template');
    isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, title => 'something'), 'HTML::Template');
    isa_ok(C4::View::Serials::SeedTemplateWithSubscriptionData($template, 1),                    'HTML::Template');

    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:0,0,0', '1:1:0')  eq '1:2:0',  'PredictNextSequenceFromSeed 1');
    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:0,0,0', '1:12:0') eq '2:1:0',  'PredictNextSequenceFromSeed 2');
    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:1,1,4', '1:11:3') eq '1:11:4', 'PredictNextSequenceFromSeed 3');
    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:1,1,4', '1:12:4') eq '2:1:1',  'PredictNextSequenceFromSeed 4');
    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:1,2,4', '1:1:3')  eq '1:2:1',  'PredictNextSequenceFromSeed 5');
    ok(C4::Control::PeriodicalSerial::PredictNextSequenceFromSeed('1,1,9999:1,1,12:2,2,4', '1:1:4')  eq '1:2:2',  'PredictNextSequenceFromSeed 6');

    my $date = DateTime->new(year => 2010, month => 01, day => 01);
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('1d', $date) eq '2010-01-02T00:00:00',   'PredictNextChronologyFromSeed 1');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('2d', $date) eq '2010-01-03T00:00:00',   'PredictNextChronologyFromSeed 2');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('1w', $date) eq '2010-01-08T00:00:00',   'PredictNextChronologyFromSeed 3');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('2w', $date) eq '2010-01-15T00:00:00',   'PredictNextChronologyFromSeed 4');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('1/4y', $date) eq '2010-04-01T00:00:00', 'PredictNextChronologyFromSeed 5');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('1y', $date) eq '2011-01-01T00:00:00',   'PredictNextChronologyFromSeed 6');
    ok(C4::Control::PeriodicalSerial::PredictNextChronologyFromSeed('2y', $date) eq '2012-01-01T00:00:00',   'PredictNextChronologyFromSeed 7');

    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn} {Zn}',   '1:12:4', '2010') eq '1 12 4',    'FormatSequence 1');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys}',        '1:3:0',  '2010') eq '2010 Summer', 'FormatSequence 2');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn+1}',      '1:12:0', '2010') eq '1 12/13',    'FormatSequence 3');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xn} {Yn} {Zn+2}', '1:12:1', '2010') eq '1 12 1/2/3',    'FormatSequence 4');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys+1}',      '1:3:0',  '2010') eq '2010 Summer/Fall', 'FormatSequence 5');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('{Xs} {Ys+2}',      '1:3:0',  '2010') eq '2010 Summer/Fall/Winter', 'FormatSequence 6');
    ok(C4::Control::PeriodicalSerialFormats::FormatSequence('Vol. {Xn} Issue {Yn} No. {Zn}', '1:12:4', '2010') eq 'Vol. 1 Issue 12 No. 4', 'FormatSequence 7');

    ok(C4::Control::PeriodicalSerialFormats::FormatVintage('Vol. 1', '2010-01-01') eq 'Vol. 1 - 2010-01-01', 'FormatVintage 1');
    ok(C4::Control::PeriodicalSerialFormats::FormatVintage(undef, '2010-01-01')    eq '2010-01-01',          'FormatVintage 2');
    ok(C4::Control::PeriodicalSerialFormats::FormatVintage('Vol. 1', undef)        eq 'Vol. 1',              'FormatVintage 3');
}

exit 0;
