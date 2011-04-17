package C4::Control::Periodical;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    UpdateOrCreate
    SearchPeriodicals
    );

use Carp;
use Try::Tiny;
use CGI;
use Rose::DB::Object::Helpers qw(column_value_pairs);
use MARC::Field;
use MARC::Record;

use Koha::Schema::Periodical;
use Koha::Schema::Periodical::Manager;
use Koha::Schema::Subscription::Manager;
use Koha::Schema::PeriodicalSerial;
use Koha::Schema::Biblio;
use Koha::Schema::Biblioitem;
use C4::Control::Subscription;
use C4::Control::PeriodicalSerial;
use C4::Biblio;
use C4::Branch qw(GetBranchName);

sub _createFirstPeriodicalSerial($$) {
    my ($query, $periodical_id) = @_;
    my $periodical_serial = Koha::Schema::PeriodicalSerial->new;
    $periodical_serial->periodical_id($periodical_id);
    $periodical_serial->sequence($query->param('first_sequence'));
    $periodical_serial->publication_date($query->param('firstacquidate'));
    $periodical_serial->vintage(C4::Control::PeriodicalSerial::FormatSequence(
        $periodical_serial->periodical->sequence_format, $periodical_serial->sequence,
        $periodical_serial->publication_date(format => '%Y')));
    $periodical_serial->save;
    return $periodical_serial->id;
}

sub _setBiblioAsPeriodical($) {
    my $biblionumber = shift or croak;

    my (undef, ($biblio)) = C4::Biblio::GetBiblio($biblionumber);
    if(not $biblio->{'serial'}) {
        my $record = C4::Biblio::GetMarcBiblio($biblionumber);
        my ($tag, $subfield) = C4::Biblio::GetMarcFromKohaField('biblio.serial', $biblio->{frameworkcode});
        if($tag) {
            if ($record->field($tag)) {
                $record->field($tag)->update($subfield => 1);
            } else {
                $record->append_fields(MARC::Field->new($tag, '', '', $subfield => 1));
            }
            C4::Biblio::ModBiblio($record, $biblionumber, $biblio->{'frameworkcode'});
        }
    }
    return 1;
}

sub UpdateOrCreate($) {
    my $query = shift;
    my $periodical_id = $query->param('periodical_id');

    $periodical_id = try {
        my $periodical = Koha::Schema::Periodical->new;
        if ($periodical_id) {
            $periodical->id($periodical_id);
            $periodical->load;
        }
        $periodical->biblionumber($query->param('biblionumber'));
        $periodical->iterator($query->param('iterator'));
        $periodical->sequence_format($query->param('sequence_format'));
        $periodical->chronology_format($query->param('chronology_format'));
        $periodical->frequency($query->param('frequency'));
        $periodical->save;

        _createFirstPeriodicalSerial($query, $periodical->id) if (not defined $query->param('periodical_id'));
        _setBiblioAsPeriodical($periodical->biblionumber);

        print $query->redirect("periodicals-detail.pl?periodical_id=".$periodical->id);
        $periodical->id;
    } catch {
        my $message = "Error creating or updating periodical: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $periodical_id;
}

sub Delete($) {
    my $query = shift or croak;
    my $periodical_id = (!ref $query) ? $query : $query->param('periodical_id');
    croak 'Unable to determine periodical_id' if not defined $periodical_id;

    my $retval = try {
        my $p = Koha::Schema::Periodical->new(id => $periodical_id)->load;
        foreach ($p->subscriptions) {
            C4::Control::Subscription::Delete($_->id);
        }
        foreach ($p->periodical_serials) {
            C4::Control::PeriodicalSerial::Delete($_->id);
        }
        $p->delete;
    }
    catch {
        my $message = "Error deleting subscription: $_\n";
        carp $message;
        $query->param(error => $message);
        undef;
    };

    return $retval;
}

sub SearchPeriodicals {
    my ($key, $value) = @_;

    $value = '%'.$value.'%';
    $value =~ s/\s/%/g;

    my $periodicals;
    if ($key eq 'title') {
        $periodicals = Koha::Schema::Periodical::Manager->get_periodicals(
            with_objects => [ 'biblio' ],
            query => [ 't2.title' => { like => $value } ],
            );
    } else {
        my $query = q{
            SELECT t1.*
            FROM periodicals t1
                NATURAL JOIN biblioitems t2
            WHERE t2.issn LIKE ?
        };
        $periodicals = Koha::Schema::Periodical::Manager->get_objects_from_sql(sql => $query, args => [ $value ]);
    }
    return $periodicals;
}

sub GetSummary {
    my $periodical_id = shift // croak;

    my $subscriptions
        = Koha::Schema::Subscription::Manager->get_subscriptions(
            query => [
                periodical_id => $periodical_id
            ],
        );
    my $summaries = [];
    for my $s (@$subscriptions) {
        my $summary = {
            branchname => GetBranchName($s->branchcode),
            summary => C4::Control::Subscription::GetSummary($s->id),
        };
        next if (scalar @{$summary->{summary}} == 0);
        push @$summaries, $summary;
    }

    return $summaries;
}

sub GetSummaryAsMarc {
    my $periodical_id = shift // croak;

    my $summaries = GetSummary($periodical_id);
    return [] if not @$summaries;

    my @summary_strings
        = map {sprintf '%s:s=[%d:%d:%d-%d:%d:%d]',
               $_->{branchname},
               $_->{summary}[0]{first}{publication_date}->year,
               $_->{summary}[0]{first}{publication_date}->month,
               $_->{summary}[0]{first}{publication_date}->day,
               $_->{summary}[0]{last}{publication_date}->year,
               $_->{summary}[0]{last}{publication_date}->month,
               $_->{summary}[0]{last}{publication_date}->day,
              } @$summaries;
    my $subf_a = join(', ', @summary_strings);

    my $f866 = MARC::Field->new(866, '3', '1', 8=>'1', a=>$subf_a);

    return [ $f866 ];
}

sub UpdateBiblioSummary {
    my $periodical_id = shift // croak;

    my $p = Koha::Schema::Periodical->new(id => $periodical_id)->load;
    my $record = GetMarcBiblio($p->biblionumber);

    my $fields = GetSummaryAsMarc($periodical_id);
    for (@$fields) {
        #FIXME CTF: This isn't going to work for multi-field tags
        $record->delete_fields($record->field($_->tag));
        $record->insert_fields_ordered($_);
    }
    C4::Biblio::ModBiblio($record, $p->biblionumber);
}

1;
