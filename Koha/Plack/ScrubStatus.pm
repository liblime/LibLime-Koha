package Koha::Plack::ScrubStatus;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util;

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);
    Plack::Util::header_remove($res->[1], 'Status');

    return $res;
}

1;
