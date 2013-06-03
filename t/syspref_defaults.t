#!/usr/bin/env perl

use Koha;
use Test::More;
use C4::Context;

my $prefs = C4::Context->preference_defaults();
is ref $prefs, 'HASH', 'Preference defaults parsable';

# Ensure defaults file entries are formed properly
for my $pref_name (keys %$prefs) {
    for my $pref_attr ( qw(value type options explanation tags hidden) ) {
        ok exists $prefs->{$pref_name}{$pref_attr}, "Pref '$pref_name' has key '$pref_attr'";
    }
}

# Check for clashing variable names
my %names;
for (sort map {lc $_} keys %$prefs) {
    ok ! exists $names{$_}, "Unique variable name $_";
    $names{$_} = 1;
}

done_testing;
