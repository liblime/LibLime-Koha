package Koha::Plack::Rewrite;
use parent qw(Plack::Middleware);

use Modern::Perl;
use Plack::Util::Accessor qw(staff_resolver);
use Carp qw(croak);

sub call {
    my ($self, $env) = @_;

    if (!defined $self->staff_resolver) {
        croak sprintf('Must define a "staff_resolver" function for %s.', __PACKAGE__);
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
