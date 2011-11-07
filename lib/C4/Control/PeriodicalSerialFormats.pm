package C4::Control::PeriodicalSerialFormats;

use Exporter 'import';

@EXPORT_OK = qw(
PredictNextSequenceFromSeed
PredictNextChronologyFromSeed
FormatSequence
FormatChronology
FormatVintage
);

use strict;
use warnings;

use Carp;
use Try::Tiny;

use C4::Model::Periodical::Chronology;

sub PredictNextSequenceFromSeed {
    my $iterator = shift or croak;
    my $seq_string = shift or croak;

    my @rules;
    foreach my $rulestring (split (/:/, $iterator)) {
        my ($start, $increment, $end) = split(/,/, $rulestring);
        my %rule = (start => $start, increment => $increment, end => $end);
        push @rules, \%rule;
    }

    my @sequence = split(/:/, $seq_string);
    $sequence[$_] //= 0 for (0..2);

    my @new_sequence;
    while (defined (my $s = pop @sequence)) {
        my $r = pop @rules;
        unshift @new_sequence, '0' and next if ($r->{increment} == 0);
        if ($s + $r->{increment} > $r->{end}) {
            unshift @new_sequence, $r->{start};
        } else {
            unshift @new_sequence, $s + $r->{increment};
            last;
        }
    }
    unshift @new_sequence, @sequence;

    my $new_seq_string = join ':', @new_sequence;

    return $new_seq_string;
}

sub PredictNextChronologyFromSeed {
    my ($frequency, $current_date) = @_;

    croak unless $current_date->isa('DateTime');

    $frequency =~ /(\d??)(\/\d)??([dwmy]{1}?)/;
    my ($numerator, $denominator, $unit) = ($1, $2, $3);
    $denominator //= 1;
    $denominator =~ s/\///;
    $unit = ($unit eq 'd') ? 'days' :
        ($unit eq 'w') ? 'weeks' :
        ($unit eq 'm') ? 'months' :
        ($unit eq 'y') ? 'years' :
        croak sprintf "invalid unit '%s'\n", $unit;
    my $new_date = $current_date->clone;
    $new_date->add($unit => $numerator/$denominator);
    return $new_date;
}

our @season_names = qw('' Winter Spring Summer Fall Winter Spring Summer Fall);

sub FormatSequence($$$) {
    my ($format, $sequence, $year) = @_;
    my $output = $format;

    my %seq = ();
    @seq{'X', 'Y', 'Z'} = split(/:/, $sequence);

    # Numeric conversion, matching formats like '{X}' or '{Xn}'
    $output =~ s/{${_}}|{${_}n}/$seq{$_}/ for (keys %seq);

    # Combined numeric issues, matching formats like '{Zn+1}'
    for my $k (keys %seq) {
        if ($output =~ /{${k}n\+(\d)}/) {
            my $combined = join '/', map {$seq{$k}+$_} (0..$1);
            $output =~ s/{${k}n\+\d}/$combined/;
        }
    }

    # Seasonal conversion
    $output =~ s/{Xs}/$year/;
    $output =~ s/{Ys}/$season_names[$seq{Y}]/;
    if ($output =~ /{Ys\+(\d)}/) {
        my $combined = join '/', map {$season_names[$seq{Y}+$_]} (0..$1);
        $output =~ s/{Ys\+\d}/$combined/;
    }

    return $output;
}

sub FormatChronology($$) {
    my ($format, $date) = @_;
    croak unless $date->isa('DateTime');
    return $date->set_formatter(C4::Model::Periodical::Chronology->new(pattern => $format));
}

sub FormatVintage($$) {
    my ($formatted_sequence, $formatted_chronology) = @_;
    my $vintage;

    $vintage .= $formatted_sequence // '';
    $vintage .= ' : ' if $formatted_sequence and $formatted_chronology;
    $vintage .= $formatted_chronology // '';
}

1;
