package C4::View::SerialsFormats;

use Exporter 'import';

@EXPORT_OK = qw(
    @frequency_formats
    @sequence_formats
    @chronology_formats
    );

use strict;
use warnings;

use C4::Control::PeriodicalSerialFormats qw(FormatSequence FormatChronology);

our %frequency_map;
our @frequency_formats;
our @sequence_formats;
our @chronology_formats;

BEGIN {
    %frequency_map = (
        '0d' => 'Unknown',
        #'1/2d' => 'Twice Daily',
        '1d' => 'Daily',
        #'1/2w' => 'Semi-weekly',
        '1w' => 'Weekly',
        '2w' => 'Bi-weekly',
        #'1/2m' => 'Semi-monthly',
        '1m' => 'Monthly',
        '1/6y' => 'Bi-monthly',
        '1/4y' => 'Quarterly',
        '1/2y' => 'Semi-annually',
        '1y' => 'Annually',
        '2y' => 'Bi-annually',
        );
    @frequency_formats = map { {format=>$_, human=>$frequency_map{$_}} } (keys %frequency_map);

    my @sequence_formats_list = (
        'v.{Xn} no.{Yn}',
        'no.{Xn}',
        'No. {Xn}',
        'Vol. {Xn}, No. {Yn}, Issue {Zn}',
        'Vol. {Xn}, No. {Yn}',
        'Vol. {Xn}, Issue {Yn}',
        'No. {Xn}, Issue {Yn}',
        '{Ys} {Xs}',
        '{Xs}/{Yn}',
        );
    @sequence_formats = map { {format=>$_, human=>FormatSequence($_, '14:2:1', '2011')} } @sequence_formats_list;

    my @chronology_formats_list = (
        '%F',
        '%m/%d/%Y',
        '%d/%m/%Y',
        '%b %d, %Y',
        '%Y %b %d',
        '%Y %b',
        '%B %d, %Y',
        '%a, %b %d, %Y',
        '%A, %B %d, %Y',
        );
    @chronology_formats = map { {format=>$_, human=>sprintf FormatChronology($_, DateTime->now)} } @chronology_formats_list;
}

1;
