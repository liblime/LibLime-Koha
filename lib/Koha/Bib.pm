package Koha::Bib;

use Moose;
use Koha;
use TryCatch;
use Koha::Solr::Query;
use Koha::Solr::Service;
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
        grep { $_->subfield('0') }
        grep { ! $_->is_control_field }
        $self->marc->fields;
    return \@headings;
}

method relink_from_headings {
    # Find matching authorities that map to this record's headings,
    # putting RCN in $0.
    my $bib_headings = Koha::HeadingMap->bib_headings;
    my @unmatched;
    my $count = 0;
    for my $f ($self->marc->fields) {
        next unless exists $bib_headings->{$f->tag};
        try {
            my $auth = Koha::BareAuthority->new_from_field_search($f);
            unless ( $auth->rcn ~~ $f->subfield('0') ) {
                $f->update( '0' => $auth->rcn );
                $f->delete_subfield( code => '9' );
                $count++;
            }
        }
        catch (Koha::BareAuthority::Xcp::NoMatch $e) {
            push @unmatched, $f;
        }
    }
    if (@unmatched) {
        Koha::Bib::Xcp::NoAuthMatch->throw(
            message => @unmatched.' unmatched fields',
            unmatched => \@unmatched);
    }
    return $count > 0;
}

method relink_with_stubbing {
    my $count = 0;
    try {
        $count += $self->relink_from_headings;
    }
    catch (Koha::Bib::Xcp::NoAuthMatch $e) {
        for my $f (@{$e->unmatched}) {
            my $auth = Koha::BareAuthority->new_stub_from_field($f);
            $auth->save;
        }
        $count += $self->relink_from_headings;
    }
    return $count > 0;
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

    package Koha::Bib::Xcp::NoAuthMatch;
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
