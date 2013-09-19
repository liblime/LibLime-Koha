package Koha::Plack::Localize;

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
use Plack::Util::Accessor qw(host_map host_mapper);
use Koha::Plack::Util;

sub regex_mapper {
    my $env = shift;
    my $host_regexes = shift;
    my $hostname = Koha::Plack::Util::GetCanonicalHostname($env);
    
    for my $r (keys %$host_regexes) {
        return $host_regexes->{$r} if ($hostname =~ $r);
    }
}

sub call {
    my ($self, $env) = @_;

    local %ENV = %ENV;

    my $config;
    if ($self->host_mapper) {
        $config = $self->host_mapper->($env);
    }
    elsif (my $configs = $self->host_map) {
        my $hostname = Koha::Plack::Util::GetCanonicalHostname($env);
        $config = $configs->{$hostname};
    }
    else {
        $config = $ENV{KOHA_CONF};
    }
    $ENV{KOHA_CONF} = $config;

    require C4::Context;
    local $C4::Context::context;
    $C4::Context::context = C4::Context->new($config);

    C4::Context->dbh->begin_work();
    my $retval = $self->app->($env);
    C4::Context->dbh->commit();

    return $retval;
}

1;
