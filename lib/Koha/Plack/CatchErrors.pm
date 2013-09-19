package Koha::Plack::CatchErrors;

#
# Copyright 2013 LibLime
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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
