#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 7;

BEGIN {
    use_ok 'C4::Koha';
}

#
# test that &slashifyDate returns correct (non-US) date
#

is '01/01/2002', slashifyDate('2002-01-01'), 'slashify';

my $opacname_tests = [
    {
        env => {
            HTTP_X_FORWARDED_HOST => "localhost.x-host.com:5000",
            HTTP_X_FORWARDED_SERVER => "localhost.x-server.com:5000,proxy.mydomain.org:1234",
            HTTP_HOST => "localhost.host.com:5000",
            SERVER_NAME => "localhost.server.com:5000",
        },
        res => 'localhost.x-host.com',
    },
    {
        env => {
            HTTP_X_FORWARDED_SERVER => "localhost.x-server.com:5000",
            HTTP_HOST => "localhost.host.com:5000",
            SERVER_NAME => "localhost.server.com:5000",
        },
        res => 'localhost.x-server.com',
    },
    {
        env => {
            HTTP_HOST => "localhost.host.com:5000",
            SERVER_NAME => "localhost.server.com:5000",
        },
        res => 'localhost.host.com',
    },
    {
        env => {
            SERVER_NAME => "localhost.server.com:5000",
        },
        res => 'localhost.server.com',
    },
    {
        env => {
        },
        res => 'koha-opac.default',
    },
];

for my $test (@$opacname_tests) {
    is C4::Koha::CgiOrPlackHostnameFinder($test->{env}), $test->{res}, 'OPAC hostname resolution';
}
