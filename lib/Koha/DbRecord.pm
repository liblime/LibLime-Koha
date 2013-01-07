package Koha::DbRecord;

use Moose::Role;
use Koha;
use Method::Signatures;

has 'dbrec' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    );

has 'id' => (
    is => 'ro',
    isa => 'Int',
    lazy_build => 1,
    );

requires qw(_build_dbrec _build_id _insert _update _delete);

method save {
    ($self->has_id) ? $self->_update : $self->_insert;
    $self->clear_dbrec;
    return;
}

method delete {
    $self->_delete;
}

no Moose::Role;
1;
