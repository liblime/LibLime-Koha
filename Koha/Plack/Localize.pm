package Koha::Plack::Localize;
use parent qw(Plack::Middleware);

use Koha;
use C4::Context;

sub call {
    my ($self, $env) = @_;

    local $C4::Context::context;
    $C4::Context::context = C4::Context->new();

    my $res = $self->app->($env);
    return $res;
}

1;
