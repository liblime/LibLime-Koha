package Koha::Plack::Util;

use Koha;

sub GetCanonicalHostname {
    my $env = shift;

    my $hostname
        =  $env->{HTTP_X_FORWARDED_HOST}
        // $env->{HTTP_X_FORWARDED_SERVER}
        // $env->{HTTP_HOST}
        // $env->{SERVER_NAME}
        // 'koha-opac.default';
    $hostname = (split qr{,}, $hostname)[0];
    $hostname =~ s/:.*//;

    return $hostname;
}

1;
