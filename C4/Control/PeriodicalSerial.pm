package C4::Control::PeriodicalSerial;

use strict;
use warnings;

use Carp;
use Try::Tiny;
use DateTime;

use C4::Model::Periodical;
use C4::Model::PeriodicalSerial;
use C4::Model::PeriodicalSerial::Manager;

use C4::Control::PeriodicalSerialFormats
    qw(PredictNextSequenceFromSeed
       PredictNextChronologyFromSeed
       FormatSequence
       FormatChronology
       FormatVintage
    );

sub GenerateNextInSeries($) {
    my $p = shift or croak;

    $p = C4::Model::Periodical->new(id => $p)->load if not ref $p;

    my $pslist = C4::Model::PeriodicalSerial::Manager->get_periodical_serials(
        query => [
            periodical_id => $p->id,
            '!sequence' => undef,
            '!sequence' => '',
        ],
        sort_by => 'publication_date DESC',
        limit => 1
        );

    my $new_seq_string = PredictNextSequenceFromSeed($p->iterator, $pslist->[0]->sequence);
    my $new_date = PredictNextChronologyFromSeed($p->frequency, $pslist->[0]->publication_date);

    my $new_ps = C4::Model::PeriodicalSerial->new(periodical_id => $p->id, sequence => $new_seq_string, publication_date => $new_date->clone);
    $new_ps->vintage(FormatVintage(
			 FormatSequence($p->sequence_format, $new_seq_string, $new_date->year),
			 FormatChronology($p->chronology_format, $new_date)
		     ));
    $new_ps->save;

    return $new_ps;
}

sub FormatSequenceOfSerial($) {
    my $ps = shift or croak;

    $ps = C4::Model::PeriodicalSerial->new(id => $ps)->load if not ref $ps;
    return FormatSequence($ps->periodical->sequence_format, $ps->sequence, $ps->publication_date(format => '%Y'));
}

sub FormatChronologyOfSerial($) {
    my $ps = shift or croak;

    $ps = C4::Model::PeriodicalSerial->new(id => $ps)->load if not ref $ps;
    return FormatChronology($ps->periodical->chronology_format, $ps->publication_date);
}

sub FormatVintageOfSerial($) {
    my $ps = shift or croak;

    $ps = C4::Model::PeriodicalSerial->new(id => $ps)->load if not ref $ps;
    return FormatVintage(FormatSequenceOfSerial($ps), FormatChronologyOfSerial($ps));
}

sub Update($) {
    my $query = shift or croak;
    my $periodical_serial_id = $query->param('periodical_serial_id') // croak;

    my $periodical_serial = try {
        my  $periodical_serial = C4::Model::PeriodicalSerial->new(id => $periodical_serial_id)->load;;
        $periodical_serial->sequence($query->param('sequence'));
        $periodical_serial->vintage($query->param('vintage'));
        $periodical_serial->publication_date($query->param('publication_date'));
        $periodical_serial->save;

        print $query->redirect("periodicals-detail.pl?periodical_id=".$periodical_serial->periodical_id);
        $periodical_serial;
    } catch {
        my $message = "Error creating or updating periodical: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $periodical_serial;
}

sub CombineSequences($$;$) {
    my $ps = shift or croak;
    my $count = shift or croak;
    my $options = shift // {};

    $ps = C4::Model::PeriodicalSerial->new(id => $ps)->load if not ref $ps;

    # Create new format with least significant sequence element set to +$count.
    my $format = $ps->periodical->sequence_format;
    $format =~ /({.*})?.*({.*})?.*{(.*)}/;
    my $newseq = sprintf '{%s+%s}', $3, $count-1;
    $format =~ s/{$3}/$newseq/;
    $ps->periodical->sequence_format($format);

    # Express a new vintage string.
    $ps->vintage(FormatVintageOfSerial($ps));

    # Incrementing this issue is done.
    $ps->save;

    # Multiply the frequency.
    my $freq = $ps->periodical->frequency;
    $freq =~ /^(\d+)(\/\d+)?([dwmy])/;
    $freq = sprintf '%d%s%s', $1*$count, $2 // '', $3;
    $ps->periodical->frequency($freq);

    # Update the iterator such that it will skip the appropriate number
    # of iterations.
    my @itr;
    for (split(/:/, $ps->periodical->iterator)) {
        my @i = (split(/,/, $_));
        push @itr, \@i;
    }
    for (reverse @itr) {
        $_->[1] *= $count and last if ($_->[1] != 0);
    }
    my @tmp_itr = map {join(',', @{$_})} (@itr);
    my $new_itr = join(':', @tmp_itr);
    $ps->periodical->iterator($new_itr);

    if ($options->{permanent}) {
        # If permanent, just save the updated periodical with its new qualities.
        $ps->periodical->save;
    } else {
        # If not permanent, then immediately generate the next $ps in the sequence
        # after resetting the sequence formatting.
        # This preseves the sequence skip for future issues.
        # Note that we do *not* save the periodical.
        $ps->periodical->load;
        $ps->periodical->iterator($new_itr);
        $ps->periodical->frequency($freq);
        GenerateNextInSeries($ps->periodical);
    }
    return $ps->id;
}

sub UncombineSequences($) {
    croak 'Not yet implemented';
}

1;
