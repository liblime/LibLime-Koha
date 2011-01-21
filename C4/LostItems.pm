package C4::LostItems;

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
use C4::Context;

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
    $VERSION = 3.00;
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);
    #Get data
    push @EXPORT, qw(
        &CreateLostItem
        &DeleteLostItem
        &GetLostItems
        &GetLostItem
    );

}

=head1 NAME

C4::LostItems

=head1 SYNOPSIS

    use C4::LostItems;

=head1 DESCRIPTION

=cut

# not exported.
# this gets the authorised value for the simplest 'Lost' item status
# for category LOST.  Note: customer must set this correctly via 
# the Authorised Values administration widget in the UI.
sub AuthValForSimplyLost
{
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT authorised_value
      FROM authorised_values
     WHERE LCASE(lib) = 'lost'
       AND category   = 'LOST'");
   $sth->execute();
   return ($sth->fetchrow_array)[0];
}

# not exported.
# returns
#  undef    does not apply
#  0        no (is lost)
#  1        yes, claims returned
sub isClaimsReturned
{
   my($itemnumber,$borrowernumber) = @_;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("
      SELECT claims_returned FROM lost_items
       WHERE itemnumber     = ?
         AND borrowernumber = ?
   ");
   $sth->execute($itemnumber,$borrowernumber);
   return ($sth->fetchrow_array)[0];
}

sub ForgiveFineForClaimsReturned
{
   my $li = shift; # lost_items hash for a single lost item-borrower pair
   my $user_borrowernumber = shift;
   my $dbh = C4::Context->dbh;
   my $sth;

   use C4::Accounts;
   my $totalAmt = 0;
   my $acctLns  = C4::Accounts::getAllAccountsByBorrowerItem(
      $$li{borrowernumber},
      $$li{itemnumber}
   );
   ## look for lost/replacement fee, which *should* be accessed only once.
   ## ignore late fees.
   ACCOUNT:
   foreach(@$acctLns) {
      if ($$_{accounttype} eq 'L') {
         C4::Accounts::refundlostitemreturned(
            $$li{borrowernumber},
            $$_{accountno}
         );
         ## change the description to something meaningful
         $sth = $dbh->prepare('UPDATE accountlines 
            SET description = ?,
                accounttype = ?
          WHERE accountno   = ?');
         $sth->execute(
            "Claims Returned $$li{title} $$li{barcode}",
            'FOR',
            $$_{accountno}
         );
         last ACCOUNT;
      }
   }

   return 1;
}

sub CreateLostItem {
    my ($itemnumber,$borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $date_lost = C4::Dates->new()->output('iso');

    # Get the item and biblio data
    my $sth = $dbh->prepare("SELECT * FROM items LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber WHERE itemnumber=?");
    $sth->execute($itemnumber);
    my $item = $sth->fetchrow_hashref;

    ## dupecheck: an item-borrower pair can only be lost once per borrower
    $sth = $dbh->prepare('SELECT id FROM lost_items
      WHERE itemnumber     = ?
        AND borrowernumber = ?');
    $sth->execute($itemnumber,$borrowernumber);
    my $id = ($sth->fetchrow_array)[0];
    if ($id) {
        ## item already lost.  don't do an INSERT, just UPDATE
        $sth = $dbh->prepare("UPDATE lost_items
           SET biblionumber   = ?,
               homebranch     = ?,
               holdingbranch  = ?,
               itemcallnumber = ?,
               itemnotes      = ?,
               location       = ?,
               itemtype       = ?,
               title          = ?,
               date_lost      = ?
         WHERE id             = ?");
       $sth->execute(
            $$item{biblionumber},
            $$item{homebranch},
            $$item{holdingbranch},
            $$item{itemcallnumber},
            $$item{itemnotes},
            $$item{location},
            $$item{itype},
            $$item{title},
            $date_lost,
            $id
       );
       return $id;
    }

    # item has never been lost before for this borrower as far as we care.
    # Copy it into lost_items.
    $sth = $dbh->prepare("INSERT into lost_items (borrowernumber,itemnumber,biblionumber,barcode,homebranch,holdingbranch,itemcallnumber,itemnotes,location,itemtype,title,date_lost) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
    $sth->execute($borrowernumber,$item->{itemnumber},$item->{biblionumber},$item->{barcode},$item->{homebranch},$item->{holdingbranch},
    $item->{itemcallnumber},$item->{itemnotes},$item->{location},$item->{itype},$item->{title},$date_lost);
    $id = $dbh->{mysql_insertid};
    return $id;
}

sub ModLostItem
{
   my %g = @_;
   die "arg 'id' required" unless $g{id};
   my $id  = $g{id}; delete($g{id});
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare(sprintf("UPDATE lost_items SET %s WHERE id=?",
         join(',', map{"$_=?"}keys %g)
      )
   );
   return $sth->execute(values %g,$id);
}

sub DeleteLostItem {
    my $lost_item_id = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM lost_items WHERE id=?");
    $sth->execute($lost_item_id);
}

sub GetLostItems {
    my $borrowernumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM lost_items WHERE borrowernumber=?");
    $sth->execute($borrowernumber);
    my @lost_items;
    while (my $row = $sth->fetchrow_hashref) {
        push @lost_items, $row;
    }
    return \@lost_items;
}

sub GetLostItem {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * from lost_items WHERE itemnumber=?");
    $sth->execute($itemnumber);
    my $lost_item = $sth->fetchrow_hashref;
    return $lost_item;
}

sub GetLostItemById
{
   my $id  = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('SELECT * FROM lost_items WHERE id=?');
   $sth->execute($id);
   return $sth->fetchrow_hashref();
}

## this function is not exported.  Please use SUPER::PACK::func() syntax.
##
## $lost_item_id is lost_items.id column
## $claims_returned is bool, set to zero to undo, set to 1 to make claim
sub MakeClaimsReturned
{
   my($lost_item_id,$claims_returned) = @_;
   $claims_returned ||= 0;
   $claims_returned   = 1 if $claims_returned;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('UPDATE lost_items 
        SET claims_returned = ?
      WHERE id              = ?');
   my $fx = $sth->execute($claims_returned,$lost_item_id);
   return $fx;
}

1;
