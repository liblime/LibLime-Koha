#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use Data::Dumper;
use C4::Context;

my $defaults = C4::Context::_get_preference_defaults();
my $sysprefs = C4::Context->dbh->selectall_hashref(
    'SELECT * FROM systempreferences', 'variable');

# This is managed elsewhere
delete $sysprefs->{Version};

say sprintf 'Auditing %d defined preferences and %d defaults:',
    scalar keys %$sysprefs, scalar keys %$defaults;

foreach my $pref (values %$sysprefs) {
    next unless ($pref->{type} ~~ 'Choice');
    my @options = split(/\|/, $pref->{options});
    if (!grep {$pref->{value} ~~ $_} @options) {
        say sprintf q{* Value for '%s' ('%s') not among valid options ('%s').},
        $pref->{variable}, ($pref->{value}//'', join q{', '}, @options);
    }
}

# Iterate over the canonical list of default prefs
foreach my $default (keys %$defaults) {
    if(!exists $sysprefs->{$default}) {
        say "* Relying on default value for '$default'";
        next;
    }

    if($defaults->{$default}{type} ne $sysprefs->{$default}{type}) {
        say sprintf q{* Type mismatch for '%s': Default: '%s', Defined: '%s'},
            $default, $defaults->{$default}{type}, $sysprefs->{$default}{type};
    }

    if(($defaults->{$default}{options} // '') ne ($sysprefs->{$default}{options} // '')) {
        say sprintf q{* Option mismatch for '%s': Default: '%s', Defined: '%s'},
            $default,
            $defaults->{$default}{options} // '(undef)',
            $sysprefs->{$default}{options} // '(undef)';
    }

    delete $sysprefs->{$default};
}

# Finally, report any prefs defined in the database but not registered in the defaults
foreach my $pref (keys %$sysprefs) {
    say "* Preference '$pref' defined, but no default registered.";
}
