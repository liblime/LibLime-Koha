package Koha::Authority;

#
# Copyright 2013 LibLime
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use Moose;
use Koha;
use Koha::Solr::Query;
use Koha::Solr::Service;
use Koha::BareAuthority;
use Koha::BareBib;
use Carp;
use Method::Signatures;

extends 'Koha::BareAuthority';

has 'bibs' => (
    is => 'ro',
    isa => 'ArrayRef[Koha::BareBib]',
    lazy_build => 1,
    );

has 'duplicates' => (
    is => 'ro',
    isa => 'ArrayRef[Koha::BareAuthority]',
    lazy_build => 1,
    );

method _build_bibs {
    my $solr = Koha::Solr::Service->new();
    my %options = ( fl => 'biblionumber', facet => 'false',
                    spellcheck => 'false', rows => 50_000 );

    my $query_string = sprintf('linked_rcn:"%s"', $self->rcn);

    my $solr_query = Koha::Solr::Query->new(
        { query => $query_string, options => \%options } );
    my $rs = $solr->search( $solr_query->query, $solr_query->options );
    croak $rs->is_error if $rs->is_error;

    my %biblionumbers =
        map {$_->{biblionumber} => 1} @{$rs->content->{response}{docs}};

    return [map {Koha::BareBib->new( id => $_ )} keys %biblionumbers];
}

method _build_duplicates {
    # FIXME: actually search for dupes
    return [];
}

method link_count {
    return scalar @{$self->bibs};
}

method is_linked {
    return $self->link_count != 0;
}

method update_bibs( ArrayRef[Koha::BareBib] $bibs = $self->bibs) {
    # find headings in linked bibs with this authority's RCN and update
    # them with the authority's 1xx.
    my ($heading) = $self->marc->field('1..');
    for my $bbib (@{$bibs}) {
        my @fields =
            grep {$_->tag >= '100' && $_->subfield('0') ~~ $self->rcn}
            $bbib->marc->fields;
        for my $orig (@fields) {
            my @ind = $self->transpose_indicators( $orig );
            my $new = MARC::Field->new(
                $orig->tag, $ind[0], $ind[1],
                map {$_->[0] => $_->[1]} $heading->subfields );
            $new->add_subfields( '0' => $self->rcn );
            $bbib->marc->insert_fields_after( $orig, $new );
            $bbib->marc->delete_fields( $orig );
        }
        $bbib->save;
    }
}

func find_unlinked( Maybe[Time] $since ) {
    # class method which find authorities with no linked bibs
    die 'unimplemented';
}

before 'delete' => method {
    croak 'This authority is still linked to bib records'
        if $self->is_linked;
};

after 'save' => method {
    $self->update_bibs;
};

method absorb( Koha::Authority $absorb_me ) {
    # rewrite all of $absorb_me's bibs to have $self->rcn linkage
    my @bibs = @{$absorb_me->bibs};
    for my $bib (@bibs) {
        my $marc = $bib->marc;
        for ($marc->fields) {
            next if $_->is_control_field;
            my $subf0 = $_->subfield('0');
            next unless $absorb_me->rcn ~~ $subf0;
            $_->update( 0 => $self->rcn );
        }
    }
    $self->update_bibs( \@bibs );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
