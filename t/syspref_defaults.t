#!/usr/bin/env perl

use Koha;
use Test::More;
use C4::Context;

my $pref_count = 349;

my $prefs = C4::Context::_seed_preference_defaults_cache();
is ref $prefs, 'HASH', 'Preference defaults parsable';

is scalar keys %$prefs, $pref_count, 'Preference defaults count';

for my $pref_name (keys %$prefs) {
    for my $pref_attr ( qw(value type options explanation) ) {
        ok exists $prefs->{$pref_name}{$pref_attr}, "Pref '$pref_name' has key '$pref_attr'";
    }
}

done_testing;
