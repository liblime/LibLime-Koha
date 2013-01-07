package Koha::Xcp;

use Moose;
use Koha;

extends 'Throwable::Error';

__PACKAGE__->meta->make_immutable;
no Moose;
1;
