#!/usr/bin/perl -w
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

my $debug = 1;
my $opacUrl = "http://" . C4::Context->preference('OPACBaseURL');
use strict;

use C4::Context;
use C4::Dates;
use C4::Message;

use Mail::Sendmail;
use Getopt::Long;
use Date::Calc qw(Add_Delta_Days);
use HTML::Template::Pro;

use Data::Dumper;

my $dbh = C4::Context->dbh;

## Step 0: Get the date from last week
  #Gets localtime on the computer executed on.
  my ($d, $m, $y) = (localtime)[3,4,5];
  #Adjust the offset to either a neg or pos number of days.
  my $offset = -7;
  #Formats the date and sets the offset to subtract 60 days form the #current date. This works with the first line above.
  my ($y2, $m2, $d2) = Add_Delta_Days($y+1900, $m+1, $d, $offset);
  #Checks to see if the month is greater than 10.
  if ($m2<10) {$m2 = "0" . $m2;};
  #Put in format of mysql date YYYY-MM-DD
  my $afterDate = $y2 . '-' . $m2 . '-' . $d2;
  if ( $debug ) { print "Date 7 Days Ago: $afterDate\n"; }

## Grab the "New Items E-mail List" Archetype
my $sth = $dbh->prepare("SELECT * FROM clubsAndServicesArchetypes WHERE title = 'New Items E-mail List'");
$sth->execute;
my $archetype = $sth->fetchrow_hashref();

## Grab all the mailing lists
$sth = $dbh->prepare("SELECT * FROM clubsAndServices WHERE clubsAndServices.casaId = ?");
$sth->execute( $archetype->{'casaId'} );

## For each mailing list, generate the list of new items, then get the subscribers, then mail the list to the subscribers
while( my $mailingList = $sth->fetchrow_hashref() ) {
  ## Get the new Items
  if ( $debug ) { print "###\nWorking On Mailing List: " . $mailingList->{'title'} . "\n"; }
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
                            dateaccessioned > ?");
  $sth2->execute( $itemtype, $callnumber, $afterDate );
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
    if ( $debug ) { print "Borrower Email: " . $borrower->{'email'} . "\n"; }
    
    my $letter;
    $letter->{'title'} = 'New Items @ Your Library: ' . $mailingList->{'title'};
    $letter->{'content'} = $email;
    $letter->{'code'} = 'MAILINGLIST';
    C4::Message->enqueue($letter, $borrower, 'email');
  }
  
  
}