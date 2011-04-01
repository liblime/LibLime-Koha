package C4::Plack::Rewrite;
use parent qw(Plack::Middleware);

use Modern::Perl;
use Plack::Util;

sub _is_staff {
    my $env = shift;

    my ($hostname) = split(/, /, $env->{HTTP_X_FORWARDED_HOST}//$env->{HTTP_HOST});
    $hostname //= $env->{SERVER_NAME};
                          
    return $hostname =~ /-staff\./;
}

sub call {
    my ($self, $env) = @_;

    if ($env->{REQUEST_URI} ~~ '/') {
        map {$env->{$_} = _is_staff($env) ? '/mainpage.pl' : '/opac/opac-main.pl'} qw{REQUEST_URI PATH_INFO};
    }
    else {
        my $prepend = (_is_staff($env)) ? '' : '/opac';
        map {$env->{$_} =~ s{^/cgi-bin/koha(.*)}{$prepend$1}} qw(REQUEST_URI PATH_INFO);
    }

    my $res = $self->app->($env);
    return $res;
}

1;
