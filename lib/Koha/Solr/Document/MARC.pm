package Koha::Solr::Document::MARC;

use Moose;
use namespace::autoclean;
use Method::Signatures;

with 'Koha::Solr::Document';

has 'record' =>
    (is => 'ro', isa => 'MARC::Record', required => 1);

method BUILD(@_) {
    $self->add_fields(
        @{$self->strategy->index_to_array($self->record)} );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
