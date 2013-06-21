package Koha::BibLinker;

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
    my $subfields = Koha::HeadingMap::bib_headings->{$f->tag}{subfields};
    my $naco = $f->as_naco( subfields => $subfields );
    my $authid = C4::Context->dbh->selectrow_arrayref(
        'SELECT authid FROM auth_header WHERE naco = ?', undef, $naco );

    Koha::BibLinker::Xcp::NoAuthMatch->throw("No match for $naco")
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
                my $new_f = MARC::Field->new(
                    $f->tag, $auth_f->indicator(1), $auth_f->indicator(2),
                    (map {@$_} $auth_f->subfields) );

                # Copy back uncontrolled subfields and $0
                my @additional =
                    map {@$_} grep {$_->[0] =~ /[iw1-9]/} $f->subfields;
                push @additional, ('e', $f->subfield('e'))
                        if $f->tag !~ /^.11$/ && $f->subfield('e');
                push @additional, ('v', $f->subfield('v'))
                    if $f->tag =~ /^4..$/ && $f->subfield('v');
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
