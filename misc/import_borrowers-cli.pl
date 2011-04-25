#!/usr/bin/perl

# Copyright 2010 PTFS, Inc.
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

# Script to take some borrowers data in a known format and load it into Koha
#
# File format
#
# cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,
# address line , address line 2, city, zipcode, contry, email, phone, mobile, fax, work email, work phone,
# alternate streetnumber, alternate streettype, alternate address line 1, alternate city,
# alternate zipcode, alternate country, alternate email, alternate phone, date of birth, branchcode,
# categorycode, enrollment date, expiry date, noaddress, lost, debarred, contact surname,
# contact firstname, contact title, borrower notes, contact relationship, ethnicity, ethnicity notes
# gender, username, opac note, contact note, password, sort one, sort two
#
# any fields except cardnumber can be blank but the number of fields must match
# dates should be in the format you have set up Koha to expect
# branchcode and categorycode need to be valid

use strict;
use warnings;

use Carp qw(cluck carp croak confess);
use Getopt::Long;
use C4::Members::Import;

sub usage {
    printf <<END;
Usage: import_borrowers-cli.pl [options]
Options:
  --infile=<filename>       : read data from filename instead of stdin
  --defaultsfile=<filename> : read defaults from filename
  --matchpoint=<string>     : match for collisions on this field
  --overwrite               : overwrite collisions with new values
  --verbose                 : be noisier
  --help                    : show this message
END
}

my ($infile, $defaultsfile, $matchpoint, $overwrite_cardnumber, $ext_preserve, $verbose, $showusage) =
    ('','','cardnumber',0,0,0,0);
my $optres = GetOptions (
    "infile=s" => \$infile,
    "defaultsfile=s" => \$defaultsfile,
    "matchpoint:s" => \$matchpoint,
    "overwrite!" => \$overwrite_cardnumber,
    "preserve!" => \$ext_preserve,
    "verbose!" => \$verbose,
    "help" => \$showusage
    );

if ($showusage) {
    usage();
    exit(0);
}

# Get a handle for our input
my $fh;
if ($infile) {
    open(INFILE, "<$infile") || croak "Cannot open input file: $!\n";
    $fh = *INFILE;
} else { # default to reading from standard input
    $fh = *STDIN;
}

# defaults file is formatted as variable/value pairs, one per line, separated
# by an '=' sign. E.g.:
# zipcode=97211
my %defaults;
if ($defaultsfile) {
    open(DEFAULTS, "<$defaultsfile") || croak "Cannot open defaults file: $!\n";
    while(<DEFAULTS>) {
	my ($var, $val) = split(/=/);
	chomp($val);
	$defaults{$var} = $val;
    }
}

# Now push the magic button
my %retval = C4::Members::Import::ImportFromFH($fh,
					       $matchpoint,
					       $overwrite_cardnumber,
					       $ext_preserve,
					       \%defaults);
close($fh);

# pull these out for convenience
my ($errors, $feedback) = ($retval{errors}, $retval{feedback});

# print out any errors that cropped up
if (@$errors != 0) {
    printf "++++ ERRORS ++++\n";
    foreach my $err (@$errors) {

	if (exists $err->{badheader}) {
	    # munged header line
	    printf "* badheader: '%s'\n", $err->{lineraw};
	} elsif (exists $err->{missing_criticals}) {
	    # essential fields that were not specified
	    printf "* missing_criticals:\n";
	    my $crits = $err->{missing_criticals};
	    foreach my $crit (@$crits) {
		foreach my $element (keys %$crit) {
		    chomp($crit->{$element});
		    printf "\t%s: '%s'\n", $element, $crit->{$element};
		}
	    }
	} else {
	    # I love when programs throw an "unknown error". But what else
	    # to do here?
	    printf "* unknown error\n";
	}
    }
    printf "-------------------------------------------------\nMESSAGES:\n";
}

# Now print out informational messages if requested
if ($verbose) {
    foreach my $f (@$feedback) {
	printf "* %s: %s\n", $f->{name}, $f->{value};
    }
    printf "\n";
    printf "Successful imports: %d\n", $retval{imported};
    printf "Record overwrites: %d\n", $retval{overwritten};
    printf "Not overwritten: %d\n", $retval{alreadyindb};
    printf "Bogus entries: %d\n", $retval{invalid};
}

# exit success if no errors, otherwise failure
exit (@$errors != 0);
