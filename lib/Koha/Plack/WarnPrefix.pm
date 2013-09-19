package Koha::Plack::WarnPrefix;

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

use strict;
use warnings;

use Koha::Plack::Util;

sub call {
    my ($self, $env) = @_;
    local $SIG{__WARN__} = sub {
        my $prefix = Koha::Plack::Util::GetCanonicalHostname($env);
        warn "[$prefix] ", @_;
    };
    $self->app->($env);
}

1;
