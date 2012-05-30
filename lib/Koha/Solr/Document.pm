package Koha::Solr::Document;

use MooseX::Role::WithOverloading;
use Method::Signatures;
use WebService::Solr::Document;

use overload
    q{""} => \&WebService::Solr::Document::to_xml;

requires 'BUILD';

has 'wss_doc' => (
    is => 'ro',
    isa => 'WebService::Solr::Document',
    default => sub {WebService::Solr::Document->new},
    handles =>
        [qw( add_fields to_xml to_element field_names value_for values_for)],
    lazy => 1,
    );

has 'strategy' => (
    is => 'ro',
    does => 'Koha::Solr::IndexStrategy',
    required => 1,
    );

no Moose::Role;
1;
