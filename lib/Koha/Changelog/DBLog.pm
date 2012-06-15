package Koha::Changelog::DBLog;
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

method update( MARC::Record $record, Str $action) {
    my $biblionumber = $record->subfield('999', 'c');
    C4::Context->dbh->do(
        q{INSERT INTO changelog (rtype, action, id) VALUES (?,?,?)},
        undef, $self->rtype, $action, $biblionumber );
}

method get_todos( Str $younger_than, Int $limit = 100 ) {
    return C4::Context->dbh->selectall_arrayref( q{
SELECT id, action, stamp FROM changelog
WHERE rtype = ?
  AND stamp > ?
  AND stamp < NOW() - INTERVAL 1 SECOND
ORDER BY stamp ASC LIMIT ?},
        {Slice=>{}}, $self->rtype, $younger_than, $limit);
}

with 'Koha::Changelog';

__PACKAGE__->meta->make_immutable;
no Moose;
1;
