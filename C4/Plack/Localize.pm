package C4::Plack::Localize;
use parent qw(Plack::Middleware);
use Modern::Perl;
use Plack::Util;

use C4::Context;

use Data::Dumper;

sub call {
    my ($self, $env) = @_;

    local $C4::Context::context;
    $C4::Context::context = C4::Context->new();

    my $res = $self->app->($env);
    return $res;
}

1;
