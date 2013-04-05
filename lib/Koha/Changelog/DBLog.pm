package Koha::Changelog::DBLog;

# Copyright 2012 PTFS/LibLime
#
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

use Koha;
use Moose;
use Method::Signatures;
use namespace::autoclean;
use C4::Context;

has 'rtype' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    );

method update( Ref|Int $record, Str $action) {
    # FIXME: Method::Signatures fails to parse type disjunction Int|MARC::Record
    my $biblionumber = (ref $record) ? $record->subfield('999', 'c') : $record;
    C4::Context->dbh->do(
        q{INSERT INTO changelog (rtype, action, id) VALUES (?,?,?)},
        undef, $self->rtype, $action, $biblionumber );
}

method get_todos( Str $younger_than ) {
    return C4::Context->dbh->selectall_arrayref( q{
SELECT id, action, stamp FROM changelog
WHERE rtype = ?
  AND stamp > ?
  AND stamp < NOW() - INTERVAL 1 SECOND
ORDER BY stamp ASC},
        {Slice=>{}}, $self->rtype, $younger_than);
}

with 'Koha::Changelog';

__PACKAGE__->meta->make_immutable;
no Moose;
1;
