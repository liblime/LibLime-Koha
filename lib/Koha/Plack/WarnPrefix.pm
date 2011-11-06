package Koha::Plack::WarnPrefix;
use parent qw(Plack::Middleware);

use strict;
use warnings;

use Koha::Plack::Util;

sub call {
    my ($self, $env) = @_;
    local $SIG{__WARN__} = sub {
        my $prefix = Koha::Plack::Util::GetCanonicalHostname($env);
        warn "[$prefix] ", @_;
    };
    $self->app->($env);
}

1;
