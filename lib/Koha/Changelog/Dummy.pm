package Koha::Changelog::Dummy;

use Koha;
use Moose;

with 'Koha::Changelog';

sub update { return; }

__PACKAGE__->meta->make_immutable;
no Moose;
1;
