#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use CGI;
use DateTime;
use DateTime::Format::DateParse;
use DateTime::Format::Strptime;

use C4::Control::PeriodicalSerialFormats qw(
    PredictNextSequenceFromSeed
    PredictNextChronologyFromSeed
    FormatChronology
    FormatSequence
    FormatVintage
    );

my $query = CGI->new();

my $output = {};

my $iterator = $query->param('iterator');
my $sequence = $query->param('sequence');
my $sequence_format = $query->param('sequence_format');
my $chronology_format = $query->param('chronology_format');
my $startdate = $query->param('startdate');
my $frequency = $query->param('frequency');
my $count = $query->param('count') // 10;

print $query->header('application/json');

my @chronology_formats;
my @chronologies;
if ($startdate and $frequency) {
    push @chronologies, DateTime::Format::DateParse->parse_datetime($startdate);
    push @chronologies, PredictNextChronologyFromSeed($frequency, $chronologies[$_]) for (0..$count-2);
    push @chronology_formats, sprintf $_->set_formatter(DateTime::Format::Strptime->new(pattern => $chronology_format // '%F')) for (@chronologies);
    $output->{chronology_formats} = \@chronology_formats;
}

my @sequence_formats;
my @sequences;
if ($iterator and $sequence and $sequence_format) {
    @sequences = ($sequence);
    push @sequences, PredictNextSequenceFromSeed($iterator, $sequences[$_]) for (0..$count-2);
    push @sequence_formats, FormatSequence($sequence_format, $sequences[$_], (defined $chronologies[$_]) ? $chronologies[$_]->year : undef) for (0..$count-1);
    $output->{sequence_formats} = \@sequence_formats;
}

my @vintages;
push @vintages, FormatVintage($sequence_formats[$_], $chronology_formats[$_]) for (0..$count-1);
$output->{vintages} = \@vintages;

printf "%s\n", to_json($output, {pretty => 0});
