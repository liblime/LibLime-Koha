package Koha;

use 5.010_000;

use warnings;
use strict;

# This is copy/pasted from Modern::Perl
{
    use mro     ();
    use feature ();

    sub import {
        warnings->import();
        strict->import();
        feature->import( ':5.10' );
        mro::set_mro( scalar caller(), 'c3' );
    }
}

our $VERSION = q{4.13.04.000};

1;
