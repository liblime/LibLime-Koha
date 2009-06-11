#!/usr/bin/perl -w

# Copyright 2009 Jesse Weaver
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

use strict;
use warnings;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Dates;
use C4::Debug;
use C4::Letters;
use File::Spec;
use Getopt::Long;

sub usage {
    print STDERR <<USAGE;
Usage: $0 [ -s STYLESHEET ] OUTPUT_DIRECTORY
  Will print all waiting print notices to
  OUTPUT_DIRECTORY/notices-CURRENT_DATE.html .
  If the filename of a CSS stylesheet is specified with -s, the contents of that
  file will be included in the HTML.
USAGE
    exit $_[0];
}

my ( $stylesheet, $help );

GetOptions(
    's:s' => \$stylesheet,
    'h|help' => \$help,
) || usage( 1 );

usage( 0 ) if ( $help );

my $output_directory = $ARGV[0];

if ( !$output_directory || !-d $output_directory ) {
    print STDERR "Error: You must specify a valid directory to dump the print notices in.\n";
    usage( 1 );
}

my $today = C4::Dates->new();
my @messages = @{ GetPrintMessages() };
exit unless( @messages );

open OUTPUT, '>', File::Spec->catdir( $output_directory, "notices-" . $today->output( 'iso' ) . ".html" );

$today = $today->output();

print OUTPUT <<HEADER;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>Print Notices for $today</title>
<style type="text/css">
<!-- .message { page-break-after: always } -->
</style>
HEADER

if ( $stylesheet ) {
    print OUTPUT "<style type=\"text/css\"><!--\n";
    open STYLESHEET, '<', $stylesheet;
    while ( <STYLESHEET> ) { print OUTPUT $_ }
    close STYLESHEET;
    print OUTPUT "--></style>\n";
}

print OUTPUT "</head><body>\n";

foreach my $message ( @messages ) {
    print OUTPUT "<div class=\"message\">\n", $message->{'content'}, "</div>\n";
    C4::Letters::_set_message_status( { message_id => $message, status => 'sent' } );
}

print OUTPUT "</body></html>\n";
