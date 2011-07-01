package Koha::Plack::Localize;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util::Accessor qw(host_map);
use Koha::Plack::Util;

sub call {
    my ($self, $env) = @_;

    my $config;
    if (my $configs = $self->host_map) {
        my $hostname = Koha::Plack::Util::GetCanonicalHostname($env);
        $config = $configs->{$hostname};
    }
    else {
        $config = $ENV{KOHA_CONF};
    }

    local %ENV;
    require C4::Context;
    local $C4::Context::context;

    $C4::Context::context = C4::Context->new($config);

    $self->app->($env);
}

1;
