package Koha::Indexable;

use Moose::Role;
use Koha;
use Method::Signatures;

with 'Koha::DbRecord';

has 'changelog' => (
    is => 'ro',
    isa => 'Koha::Changelog',
    lazy_build => 1,
    );

after 'save' => method {
    $self->changelog->update($self->id, 'update');
};

after 'delete' => method {
    $self->changelog->update($self->id, 'delete');
};

1;
