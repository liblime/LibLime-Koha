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
use DateTime::Format::Strptime;

use C4::Model::Periodical;
use C4::Model::Periodical::Manager;
use C4::Model::PeriodicalSerial;
use C4::Model::PeriodicalSerial::Manager;
use C4::Model::Biblio;
use C4::Model::Biblio::Manager;
use C4::Model::Biblioitem;
use C4::Model::Biblioitem::Manager;
use C4::Biblio;

sub _create_first_periodicalserial($$) {
    my ($query, $periodical_id) = @_;
    my $periodical_serial = C4::Model::PeriodicalSerial->new;
    $periodical_serial->periodical_id($periodical_id);
    $periodical_serial->sequence($query->param('first_sequence'));
    $periodical_serial->publication_date($query->param('firstacquidate'));
    $periodical_serial->vintage(C4::Control::PeriodicalSerial::FormatSequence(
        $periodical_serial->periodical->sequence_format, $periodical_serial->sequence,
        $periodical_serial->publication_date(format => '%Y')));
    $periodical_serial->save;
    return $periodical_serial->id;
}

sub _set_biblio_as_periodical($) {
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
        my $periodical = C4::Model::Periodical->new;
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

        _create_first_periodicalserial($query, $periodical->id) if (not defined $query->param('periodical_id'));
        _set_biblio_as_periodical($periodical->biblionumber);

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

sub SearchPeriodicals {
    my ($key, $value) = @_;

    $value = '%'.$value.'%';
    $value =~ s/\s/%/g;

    my $periodicals;
    if ($key eq 'title') {
        $periodicals = C4::Model::Periodical::Manager->get_periodicals(
            with_objects => [ 'biblio' ],
            query => [ 't2.title' => { like => $value } ],
            );
    } else {
        my $query = q{
            SELECT t1.* FROM periodicals t1 NATURAL JOIN biblioitems t2 WHERE t2.issn LIKE ?
        };
        $periodicals = C4::Model::Periodical::Manager->get_objects_from_sql(sql => $query, args => [ $value ]);
    }
    return $periodicals;
}

1;
