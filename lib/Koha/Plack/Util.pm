package Koha::Plack::Util;

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

use Koha;

sub GetCanonicalHostname {
    my $env = shift;

    my $hostname
        =  $env->{HTTP_X_FORWARDED_HOST}
        // $env->{HTTP_X_FORWARDED_SERVER}
        // $env->{HTTP_HOST}
        // $env->{SERVER_NAME}
        // 'koha-opac.default';
    $hostname = (split qr{,}, $hostname)[0];
    $hostname =~ s/:.*//;

    return $hostname;
}

sub IsStaff {
    my $hostname = GetCanonicalHostname(shift);
    return 1 if $ENV{KOHA_STAFF};
    return $hostname =~ /-staff/;
}

sub RedirectRootAndOpac {
    my $env = shift;
    my $is_staff = shift // \&IsStaff;

    return 302 if ($is_staff->($env) && s{^/$}{/cgi-bin/koha/mainpage.pl});
    return 302 if (!$is_staff->($env) && s{^/$}{/cgi-bin/koha/opac-main.pl});
    if (!$is_staff->($env)) { s{^/cgi-bin/koha/}{/cgi-bin/koha/opac/}}
    return;
}

1;
