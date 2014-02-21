package Koha::BibLinker;

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

use Koha;
use Moose;
use Koha::HeadingMap;
use MARC::Field::Normalize::NACO;
use Koha::Xcp;
use C4::Context;
use Encode qw(encode_utf8);
use TryCatch;
use Method::Signatures;

# $f is a controlled bib field, like a 1xx, 6xx, 7xx, etc.
method find_auth_from_bib_field( MARC::Field $f ) {
    my $headmap = Koha::HeadingMap::bib_headings->{$f->tag};
    my $naco = $f->as_naco( subfields => $headmap->{subfields} );
    my $authid = C4::Context->dbh->selectrow_arrayref(
        'SELECT authid FROM auth_header WHERE naco=? AND authtypecode=? '.
        'ORDER BY datemodified DESC LIMIT 1', undef,
        $naco, $headmap->{auth_type} );

    Koha::BibLinker::Xcp::NoAuthMatch->throw(
        "No match for '$naco' ($headmap->{auth_type})")
          unless $authid;

    return Koha::BareAuthority->new( id => $authid->[0] );
}

method relink_from_headings( Koha::BareBib $bib ) {
    # Find matching authorities that map to this record's headings,
    # putting RCN in $0.
    my $bib_headings = Koha::HeadingMap->bib_headings;
    my @unmatched;
    my $count = 0;
    for my $f ($bib->marc->fields) {
        next unless exists $bib_headings->{$f->tag};
        try {
            my $auth = $self->find_auth_from_bib_field( $f );
            unless ( $auth->rcn ~~ $f->subfield('0') ) {
                my $auth_f = $auth->marc->field('1..');
                my @ind = $auth->transpose_indicators( $f );
                my $new_f = MARC::Field->new(
                    $f->tag, $ind[0], $ind[1], (map {@$_} $auth_f->subfields) );

                # Copy back uncontrolled subfields and $0
                my @additional =
                    map {@$_} grep {$_->[0] =~ /[iw1-9]/} $f->subfields;
                push @additional, ('e', $f->subfield('e'))
                        if $f->tag !~ /^.11$/ && $f->subfield('e');
                push @additional, ('v', $f->subfield('v'))
                    if $f->tag =~ /^4..$|^8..$/ && $f->subfield('v');
                $new_f->add_subfields( @additional, '0' => $auth->rcn );

                $f->replace_with( $new_f );
                $count++;
            }
        }
        catch (Koha::BibLinker::Xcp::NoAuthMatch $e) {
            push @unmatched, $f;
        }
    }
    if (@unmatched) {
        Koha::BibLinker::Xcp::UnmatchedFields->throw(
            message => @unmatched.' unmatched fields',
            unmatched => \@unmatched);
    }
    return $count > 0;
}

method relink_with_stubbing( Koha::BareBib $bib ) {
    my $count = 0;
    try {
        $count += $self->relink_from_headings( $bib );
    }
    catch (Koha::BibLinker::Xcp::UnmatchedFields $e) {
        my %unmatched;
        for (@{$e->unmatched}) {
            # uniqueify in case we have identical headings in the same bib
            $unmatched{$_->as_naco} = $_;
        }
        for (values %unmatched) {
            my $auth = Koha::BareAuthority->new_stub_from_field($_);
            $auth->save;
        }
        $count += $self->relink_from_headings( $bib );
    }
    return $count > 0;
}

__PACKAGE__->meta->make_immutable;
no Moose;

{
    package Koha::BibLinker::Xcp::NoAuthMatch;
    use Moose;
    extends 'Koha::Xcp';
    __PACKAGE__->meta->make_immutable;
    no Moose;


    package Koha::BibLinker::Xcp::UnmatchedFields;
    use Moose;
    extends 'Koha::Xcp';

    has 'unmatched' => (
        is => 'ro',
        isa => 'ArrayRef',
        required => 1,
        );

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

1;
