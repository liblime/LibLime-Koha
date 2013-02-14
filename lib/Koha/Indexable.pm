package Koha::Indexable;

use Moose::Role;
use Koha;
use Koha::Solr::Service;
use Method::Signatures;

with 'Koha::DbRecord';

has 'changelog' => (
    is => 'ro',
    isa => 'Koha::Changelog',
    lazy_build => 1,
    );

requires qw( _build_changelog );

after 'save' => method {
    $self->changelog->update($self->id, 'update');
};

after 'delete' => method {
    $self->changelog->update($self->id, 'delete');
};

1;
