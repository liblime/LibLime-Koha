package Koha::Plack::Rewrite;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util::Accessor qw(staff_resolver);
use Carp qw(croak);
use Koha::Plack::Util;

sub is_staff {
    my $hostname = Koha::Plack::Util::GetCanonicalHostname(shift);
    return $hostname =~ /-staff\./;
}

sub call {
    my ($self, $env) = @_;

    if (!defined $self->staff_resolver) {
        $self->staff_resolver(\&is_staff);
    }

    if ($env->{REQUEST_URI} ~~ '/') {
        map {$env->{$_} = $self->staff_resolver->($env) ? '/mainpage.pl' : '/opac/opac-main.pl'} qw{REQUEST_URI PATH_INFO};
    }
    else {
        my $prepend = ($self->staff_resolver->($env)) ? '' : '/opac';
        map {$env->{$_} =~ s{^/cgi-bin/koha(.*)}{$prepend$1}} qw(REQUEST_URI PATH_INFO);
    }

    my $res = $self->app->($env);
    return $res;
}

1;
