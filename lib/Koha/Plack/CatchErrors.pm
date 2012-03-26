package Koha::Plack::CatchErrors;
use parent qw(Plack::Middleware);

use Koha;
use Plack::Util::Accessor qw(logger);
use Plack::Request;
use Try::Tiny;
use Data::Dumper;

sub call {
    my ($self, $env) = @_;

    my $req = Plack::Request->new($env);

    my $retval = try {
        $self->app->($env);
    }
    catch {
        my $eid = sprintf '%08x', rand(2**31);
        my $error = "EXCEPTION($eid):$_".Dumper($env).Dumper($req->parameters());
        if (my $log = $self->logger) {
            $log->error($error);
        }
        else {
            warn $error;
        }

        return [
            500,
            [],
            ["Internal Server Error (support code $eid)\n"]
        ];
    };
}

1;
