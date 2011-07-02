package Koha::Plack::Benchmark;
use parent qw(Plack::Middleware);

use Koha;
use Time::HiRes qw(gettimeofday tv_interval);

sub call {
    my ($self, $env) = @_;
    my $t0 = [gettimeofday];
    my $res = $self->app->($env);
    my $elapsed = tv_interval ( $t0 );
    printf STDERR "BENCHMARK:%.05f:%s\n", $elapsed, $env->{REQUEST_URI};

    return $res;
}

1;
