package Koha::BibLinker;

use Koha;
use Moose;
use Koha::Solr::Service;
use Koha::HeadingMap;
use Koha::Xcp;
use C4::Context;
use Encode qw(encode_utf8);
use TryCatch;
use Method::Signatures;

has 'solr' => (
    is => 'ro',
    isa => 'Koha::Solr::Service',
    lazy_build => 1,
    );

method _build_solr {
    return Koha::Solr::Service->new;
}

func _field2cstr( MARC::Field $f, Str $subfields = 'a-z68' ) {
    return join '', map {"\$$_->[0]$_->[1]"}
        grep {$_->[0] =~ qr([$subfields])} $f->subfields;
}

# $f is a controlled bib field, like a 1xx, 6xx, 7xx, etc.
method find_auth_from_bib_field( MARC::Field $f ) {
    # first see if there's a cached entry
    my $cstr = _field2cstr(
        $f, Koha::HeadingMap::bib_headings->{$f->tag}{subfields});
    my $hash = Digest::SHA1::sha1_base64( encode_utf8($cstr) );
    my $cached_authid = C4::Context->dbh->selectrow_arrayref(
        'SELECT authid FROM auth_cache WHERE tag = ?', undef, $hash );
    return Koha::BareAuthority->new( id => $cached_authid->[0] )
        if $cached_authid;

    # if not, look in the Solr index, choosing the most recently updated
    my $query = Koha::Solr::Query->new(
        query => qq{coded-heading_s:"$cstr"},
        rtype => 'auth',
        options => {fl=>'rcn', sort=>'timestamp desc', rows=>1} );
    my $rs = $self->solr->search( $query->query, $query->options);

    Koha::Xcp->throw($rs->content->{error}{msg}) if $rs->is_error;
    my $resultset = $rs->content;
    Koha::BibLinker::Xcp::NoAuthMatch->throw("No match for $cstr")
        if $resultset->{response}{numFound} < 1;

    my $rcn = $resultset->{response}{docs}[0]{rcn};
    return Koha::BareAuthority->new( rcn => $rcn );
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
                $f->update( '0' => $auth->rcn );
                $f->delete_subfield( code => '9' );
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
        for my $f (@{$e->unmatched}) {
            my $auth = Koha::BareAuthority->new_stub_from_field($f);
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
