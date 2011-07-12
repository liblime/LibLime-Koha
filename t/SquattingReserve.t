#!/usr/bin/env perl

use Koha;
use Test::More tests => 5;

BEGIN {
      use_ok('Koha::Squatting::Reserve');
}

my @hdrs = (
    {
        content => 'application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        retval => 'application/json',
    },
    {
        content => 'text/html,application/json,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        retval => 'text/html',
    },
    {
        content => 'application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        retval => undef,
    },
    {
        content => undef,
        retval => undef,
    },
);

for my $t (@hdrs) {
    my $retval = Koha::Squatting::Reserve::Controllers::_GetPreferredContentType($t->{content});
    is $retval, $t->{retval},
        q{Check preferred content for } . ($t->{content} // '[undef]');
}
