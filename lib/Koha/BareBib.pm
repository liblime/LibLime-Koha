package Koha::BareBib;

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
use Koha::Xcp;
use C4::Context;
use Method::Signatures;

with 'Koha::MarcRecord';
with 'Koha::DbRecord';
with 'Koha::Indexable';

method _build_marc {
    return MARC::Record->new_from_usmarc($self->dbrec->{marc});
}

method _build_id {
    return $self->marc->subfield('999', 'c');
}

method _build_dbrec {
    return C4::Context->dbh->selectrow_hashref(
        'SELECT * FROM biblio b
           JOIN biblioitems bi ON (b.biblionumber = bi.biblionumber)
         WHERE b.biblionumber = ?', undef, $self->id);
}

method _build_changelog {
    return Koha::Changelog::DBLog->new( rtype => 'biblio' )
}

method _insert {
    Koha::Xcp->throw('Unimplemented');
}

method _update {
    C4::Context->dbh->do(
        'UPDATE biblioitems SET marc=?, marcxml=? WHERE biblionumber=?',
        undef, $self->marc->as_usmarc, $self->marc->as_xml, $self->id );
    $self->changelog->update($self->id, 'update');
}

method _delete {
    Koha::Xcp->throw('Unimplemented');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
