package Koha::Authority;

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
    my %options = ( fl => 'biblionumber', facet => 'false', spellcheck => 'false' );

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
            my $new = MARC::Field->new(
                $orig->tag, $heading->indicator(1), $heading->indicator(2),
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
    # FIXME: rewrite all the appropriate fields in $absorb_me->bibs
    # to match $self
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
