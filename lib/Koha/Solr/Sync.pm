package Koha::Solr::Sync;

use Koha;
use Moose;
use Method::Signatures;
use Log::Dispatch;

has 'subject' => (
    is => 'ro',
    isa => 'string',
    required => 1,
    );

has 'todos' => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
    );

has 'log' => (
    is => 'ro',
    isa => 'Log::Dispatch',
    default => sub { Log::Dispatch->new },
    );

method _build_todos(@_) {
}

1;
