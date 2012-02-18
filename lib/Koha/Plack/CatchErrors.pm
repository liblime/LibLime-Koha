package Koha::Plack::CatchErrors;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util::Accessor qw(logger);
use Try::Tiny;

sub call {
    my ($self, $env) = @_;

    my $retval = try {
        $self->app->($env);
    }
    catch {
        my $error = "KOHA_PLACK_ERROR:$_".Data::Dumper::Dumper($env).Data::Dumper::Dumper(\%ENV);
        if (my $log = $self->logger) {
            $log->error($error);
        }
        else {
            warn $error;
        }

        return [
            500,
            [],
            ["Internal Server Error<br/>\n"]
        ];
    };
}

1;
