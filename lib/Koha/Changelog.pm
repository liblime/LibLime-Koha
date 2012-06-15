package Koha::Changelog;
use Koha;
use Moose::Role;
use Method::Signatures;

requires 'update';

no Moose::Role;
1;
