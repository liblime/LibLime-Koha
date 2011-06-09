#!/usr/bin/env perl
#-----------------------------------
# Description: This script generates e-mails
# sent to subscribers of e-mail lists from
# the New Items E-mail List archetype
# in the ClubsAndServices module
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

# DOCUMENTATION
# This script utilizes the 'New Items E-mail List' archetype
# from the ClubsAndServices.pm module.
# If you do not have this archtype, create an archetype of that name
# with club/service data 1 as Itemtype, and club/service data 2 as Callnumber.
# No other data is needed.

# The script grabs all new items with the given itemtype and callnumber.
# When creating lists to use this script, use % as a wildcard.
# If all your science fiction books are of itemtype FIC and have a callnumber
# beginning with 'FIC SF', then you would create a service based on this
# Archetype and input 'FIC' as the Itemtype, and 'FIC SF%' as the Callnumber.

# The e-mails are based on the included HTML::Template file mailinglist.tmpl
# If you would like to modify the style of the e-mail, just alter that file.

use strict;

use Koha;
use C4::Context;
use C4::Dates;
use C4::Message;

use Mail::Sendmail;
use Getopt::Long;
use Date::Calc qw(Add_Delta_Days);
use HTML::Template::Pro;

use Data::Dumper;

use Getopt::Long;
my ( $name, $start, $end, $help );
my $verbose = 0;
GetOptions(
  'name=s' => \$name,
  'start=i' => \$start,
  'end=i' => \$end,
  'verbose' => \$verbose,
  'help' => \$help,
);

if ( $help ) {
  print "\nmailinglist.pl --name [Club Name] --start [Days Ago] --end [Days Ago]\n\n";
  print "Example: 'mailinglist.pl --name \"My Club' --start 7 --end 0\" will send\na list of items cataloged since last week to the members of the club\nnamed MyClub\n\n";
  print "All arguments are optional. Defaults are to run for all clubs, with dates from 7 to 0 days ago.\n\n";
  exit;
}

unless( C4::Context->preference('OPACBaseURL') ) { die("Koha System Preference 'OPACBaseURL' is not set!"); }
my $opacUrl = 'http://' . C4::Context->preference('OPACBaseURL');
        
my $dbh = C4::Context->dbh;
my $sth;

## Step 0: Get the date from last week
  #Gets localtime on the computer executed on.
  my ($d, $m, $y) = (localtime)[3,4,5];

  ## 0.1 Get start date
  #Adjust the offset to either a neg or pos number of days.
  my $offset = -7;
  if ( $start ) { $offset = $start * -1; }
  #Formats the date and sets the offset to subtract 60 days form the #current date. This works with the first line above.
  my ($y2, $m2, $d2) = Add_Delta_Days($y+1900, $m+1, $d, $offset);
  #Checks to see if the month is greater than 10.
  if ($m2<10) {$m2 = "0" . $m2;};
  #Put in format of mysql date YYYY-MM-DD
  my $afterDate = $y2 . '-' . $m2 . '-' . $d2;
  if ( $verbose ) { print "Date $offset Days Ago: $afterDate\n"; }

  ## 0.2 Get end date
  #Adjust the offset to either a neg or pos number of days.
  $offset = 0;
  if ( $end ) { $offset = $end * -1; }
  ($y2, $m2, $d2) = Add_Delta_Days($y+1900, $m+1, $d, $offset);
  if ($m2<10) {$m2 = "0" . $m2;};
  my $beforeDate = $y2 . '-' . $m2 . '-' . $d2;
  if ( $verbose ) { print "Date $offset Days Ago: $beforeDate\n"; }

if ( $name ) {

  $sth = $dbh->prepare("SELECT * FROM clubsAndServices WHERE clubsAndServices.title = ?");
  $sth->execute( $name );
  
} else { ## No name given, process all items

  ## Grab the "New Items E-mail List" Archetype
  $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE title = 'New Items E-mail List'");
  $sth->execute;
  my $archetype = $sth->fetchrow_hashref();

  ## Grab all the mailing lists
  $sth = $dbh->prepare("SELECT * FROM clubsAndServices WHERE clubsAndServices.casaId = ?");
  $sth->execute( $archetype->{'casaId'} );
  
}

## For each mailing list, generate the list of new items, then get the subscribers, then mail the list to the subscribers
while( my $mailingList = $sth->fetchrow_hashref() ) {
  ## Get the new Items
  if ( $verbose ) { print "###\nWorking On Mailing List: " . $mailingList->{'title'} . "\n"; }
  my $itemtype = $mailingList->{'casData1'};
  my $callnumber = $mailingList->{'casData2'};
  ## If either are empty, ignore them with a wildcard
  if ( ! $itemtype ) { $itemtype = '%'; }
  if ( ! $callnumber ) { $callnumber = '%'; }
  
  my $sth2 = $dbh->prepare("SELECT
                            biblio.author, 
                            biblio.title, 
                            biblio.biblionumber,
                            biblioitems.isbn, 
                            items.itemcallnumber
                            FROM 
                            items, biblioitems, biblio
                            WHERE
                            biblio.biblionumber = biblioitems.biblionumber AND
                            biblio.biblionumber = items.biblionumber AND
                            biblioitems.itemtype LIKE ? AND
                            items.itemcallnumber LIKE ? AND
                            dateaccessioned >= ? AND
                            dateaccessioned <= ?");
  $sth2->execute( $itemtype, $callnumber, $afterDate, $beforeDate );
  my @newItems;
  while ( my $row = $sth2->fetchrow_hashref ) {
    $row->{'opacUrl'} = $opacUrl;
    push( @newItems , $row );
  }
print Dumper ( @newItems );
  $sth2->finish;
  my $newItems = \@newItems;          
  my $template = HTML::Template->new( filename => 'mailinglist.tmpl' );
  $template->param( 
                    listTitle => $mailingList->{'title'},
                    newItemsLoop => $newItems,
                  );
  my $email = $template->output;
  
  ## Get all the members subscribed to this list
  $sth2 = $dbh->prepare("SELECT * FROM clubsAndServicesEnrollments, borrowers 
                         WHERE
                         borrowers.borrowernumber = clubsAndServicesEnrollments.borrowernumber AND
                         clubsAndServicesEnrollments.dateCanceled IS NULL AND
                         clubsAndServicesEnrollments.casId = ?");
  $sth2->execute( $mailingList->{'casId'} );
  while ( my $borrower = $sth2->fetchrow_hashref() ) {
    if ( $verbose ) { print "Borrower Email: " . $borrower->{'email'} . "\n"; }
    
    my $letter;
    $letter->{'title'} = 'New Items @ Your Library: ' . $mailingList->{'title'};
    $letter->{'content'} = $email;
    $letter->{'code'} = 'MAILINGLIST';
    C4::Message->enqueue($letter, $borrower, 'email');
  }
  
  
}