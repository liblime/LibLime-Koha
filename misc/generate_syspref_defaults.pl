#!/usr/bin/env perl

use warnings;
use strict;
use Koha;
use C4::Context;
use JSON;

my $prefs = C4::Context->dbh->selectall_hashref(
    'SELECT variable, value, options, explanation, type FROM systempreferences',
    'variable');

for (values %$prefs) {
    delete $_->{variable};
}

print to_json($prefs, {pretty=>1} );
