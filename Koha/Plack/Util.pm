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

sub IsStaff {
    my $hostname = GetCanonicalHostname(shift);
    return $hostname =~ /-staff/;
}

sub RedirectRootAndOpac {
    my $env = shift;
    my $is_staff = shift // \&IsStaff;

    return 302 if ($is_staff->($env) && s{^/$}{/cgi-bin/koha/mainpage.pl});
    return 302 if (!$is_staff->($env) && s{^/$}{/cgi-bin/koha/opac-main.pl});
    if (!$is_staff->($env)) { s{^/cgi-bin/koha/}{/cgi-bin/koha/opac/}}
    return;
}

1;
