package Koha::Changelog::DBLog;
use Koha;
use Moose;
use namespace::autoclean;
use C4::Context;
use Method::Signatures;

method update ( Int|MARC::Record $record, Str $action ) {
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
