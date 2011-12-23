package Koha::Plack::Localize;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util::Accessor qw(host_map host_mapper);
use Koha::Plack::Util;

sub regex_mapper {
    my $env = shift;
    my $host_regexes = shift;
    my $hostname = Koha::Plack::Util::GetCanonicalHostname($env);
    
    for my $r (keys %$host_regexes) {
        return $host_regexes->{$r} if ($hostname =~ $r);
    }
}

sub call {
    my ($self, $env) = @_;

    my $config;
    if ($self->host_mapper) {
        $config = $self->host_mapper->($env);
    }
    elsif (my $configs = $self->host_map) {
        my $hostname = Koha::Plack::Util::GetCanonicalHostname($env);
        $config = $configs->{$hostname};
    }
    else {
        $config = $ENV{KOHA_CONF};
    }

    local %ENV = %ENV;
    require C4::Context;
    local $C4::Context::context;

    $C4::Context::context = C4::Context->new($config);

    require Koha::RoseDB;

    Koha::RoseDB->register_db(
        domain   => Koha::RoseDB->default_domain,
        type     => Koha::RoseDB->default_type,
        driver   => 'mysql',
        database => C4::Context->config('database'),
        host     => C4::Context->config('hostname'),
        port     => C4::Context->config('port'),
        username => C4::Context->config('user'),
        password => C4::Context->config('pass'),
        connect_options => {
            RaiseError => 1,
            AutoCommit => 1,
        },
        );

    my $retval = $self->app->($env);

    Koha::RoseDB->unregister_db(domain=>Koha::RoseDB->default_domain, type=>Koha::RoseDB->default_type);

    return $retval;
}

1;
