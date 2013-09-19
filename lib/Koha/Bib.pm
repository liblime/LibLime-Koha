package Koha::Bib;

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
use TryCatch;
use Koha::Xcp;
use Koha::HeadingMap;
use Koha::BareAuthority;
use Method::Signatures;

extends 'Koha::BareBib';

has 'authorities' => (
    is => 'ro',
    isa => 'ArrayRef[Koha::BareAuthority]',
    lazy_build => 1,
    );

has 'items' => (
    is => 'ro',
    isa => 'ArrayRef[Koha::Item]',
    lazy_build => 1,
    );

method _build_authorities {
    my @headings =
        map { Koha::BareAuthority->new( rcn => $_ ) }
        grep { $_->subfield('0') }
        grep { ! $_->is_control_field }
        $self->marc->fields;
    return \@headings;
}

method update_from_rcns {
    # Find each heading's matching auth by RCN and update the heading
    # subfields if it differs from the authority.
    for my $f ($self->marc->fields) {
        next unless exists Koha::HeadingMap::bib_headings->{$f->tag};

        my $subf0 = $f->subfield('0');
        Koha::Bib::Xcp::NoRcn->throw( 'No RCN for tag '.$f->tag )
            unless $subf0;

        my $auth = Koha::Authority->new(rcn => $subf0);
        try {
            $auth->id;
        }
        catch {
            Koha::Bib::Xcp::BadRcn->throw('Bad RCN for tag '.$f->tag);
        }
        $auth->update_bibs( [$self] );
    }
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

{
    package Koha::Bib::Xcp::NoRcn;
    use Moose;
    extends 'Koha::Xcp';
    __PACKAGE__->meta->make_immutable;
    no Moose;

    package Koha::Bib::Xcp::BadRcn;
    use Moose;
    extends 'Koha::Xcp';
    __PACKAGE__->meta->make_immutable;
    no Moose;
}

1;
