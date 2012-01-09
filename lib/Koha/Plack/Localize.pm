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

    local %ENV = %ENV;

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

    require C4::Context;
    local $C4::Context::context;
    $C4::Context::context = C4::Context->new($config);

    C4::Context->dbh->begin_work();
    my $retval = $self->app->($env);
    C4::Context->dbh->commit();

    return $retval;
}

1;
