package C4::View::SerialsFormats;

use Exporter 'import';

@EXPORT_OK = qw(
    @frequency_formats
    @sequence_formats
    @chronology_formats
    );

use strict;
use warnings;

our %frequency_map;
our @frequency_formats;

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
}

our @sequence_formats = (
    {format => 'v.{Xn} no.{Yn}', human => 'v.14 no.2'},
    {format => 'no.{Xn}', human => 'no.14'},
    {format => 'No. {Xn}', human => 'No. 14'},
    {format => 'Vol. {Xn}, No. {Yn}, Issue {Zn}', human => 'Vol. 14, No. 2, Issue 1'},
    {format => 'Vol. {Xn}, No. {Yn}', human => 'Vol 14, No. 2'},
    {format => 'Vol. {Xn}, Issue {Yn}', human => 'Vol. 14, Issue 2'},
    {format => 'No. {Xn}, Issue {Yn}', human => 'No. 14, Issue 2'},
    {format => '{Ys} {Xs}', human => 'Fall 2010'},
    {format => '{Xs}/{Yn}', human => '2010/17'},
    );

our @chronology_formats = (
    {format => '%F', human => '2010-02-19'},
    {format => '%m/%d/%Y', human => '02/19/2010'},
    {format => '%d/%m/%Y', human => '19/02/2010'},
    {format => '%b %d, %Y', human => 'Feb 19, 2010'},
    {format => '%Y %b %d', human => '2010 Feb 19'},
    {format => '%Y %b', human => '2010 Feb'},
    {format => '%B %d, %Y', human => 'February 19, 2010'},
    {format => '%a, %b %d, %Y', human => 'Fri, Feb 19, 2010'},
    {format => '%A, %B %d, %Y', human => 'Friday, February 19, 2010'},
    );

1;
