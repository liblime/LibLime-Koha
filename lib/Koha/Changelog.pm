package Koha::Changelog;
use Koha;
use Moose::Role;
use Method::Signatures;

requires 'update';

has 'rtype' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    );

no Moose::Role;
1;
