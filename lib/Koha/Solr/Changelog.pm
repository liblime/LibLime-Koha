package Koha::Solr::Changelog;
use Koha;
use Moose;
use Method::Signatures;
use namespace::autoclean;
use WebService::Solr;
use C4::Context;

has 'server' => (
    is => 'ro',
    isa => 'WebService::Solr',
    handles => [ qw( update delete_by_id ) ],
    default => sub {
        WebService::Solr->new( C4::Context->config('solr')->{url},
                               { autocommit => 0 } );
    },
    lazy => 1,
);

with 'Koha::Changelog';

__PACKAGE__->meta->make_immutable;
no Moose;
1;
