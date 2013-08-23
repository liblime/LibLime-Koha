package Koha;

use 5.014_000;

use warnings;
use strict;

# This is copy/pasted from Modern::Perl
{
    use mro     ();
    use feature ();

    sub import {
        warnings->import();
        strict->import();
        feature->import( ':5.14' );
        mro::set_mro( scalar caller(), 'c3' );
    }
}

our $VERSION = q{4.17.02.000};

1;
