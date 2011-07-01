package Koha::Plack::Util;

use Koha;

sub GetCanonicalHostname {
    my $env = shift;
    my ($hostname) = split(/, /, $env->{HTTP_X_FORWARDED_HOST}//$env->{HTTP_HOST});
    $hostname //= $env->{SERVER_NAME};
    return $hostname;
}

1;
