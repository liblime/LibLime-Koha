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
use Koha;
use C4::Context;
use C4::Items;

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

sub CreateLostItem {
    my ($itemnumber,$borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $date_lost = C4::Dates->new()->output('iso');

    # Get the item and biblio data
    my $sth = $dbh->prepare("
      SELECT items.*,biblio.title FROM items,biblio
       WHERE items.itemnumber=?
         AND items.biblionumber=biblio.biblionumber");
    $sth->execute($itemnumber);
    my $item = $sth->fetchrow_hashref;
    $$item{itype} //= $$item{itemtype};

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

# FIXME: Some libraries seem to want to keep a lost item record around
# even after the item is found.  This would break that.
sub DeleteLostItemByItemnumber
{
   my $itemnumber = shift;
   C4::Context->dbh->do('DELETE FROM lost_items WHERE itemnumber=?',undef,$itemnumber);
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
    my $sth = $dbh->prepare("SELECT li.*, biblio.title AS biblio_title
        FROM lost_items li LEFT JOIN biblio USING(biblionumber)
        WHERE borrowernumber=? ORDER BY date_lost DESC");
    $sth->execute($borrowernumber);
    my @lost_items;
    my $sth_item = $dbh->prepare("SELECT itemlost from items WHERE itemnumber=?");
    # FIXME: We should test for the bib here and not link to it if it was deleted.
    while (my $row = $sth->fetchrow_hashref) {
        $sth_item->execute($row->{itemnumber});
        $row->{itemlost} = $sth_item->fetchrow_arrayref->[0];
        warn $row->{itemlost} ;
        if(!$sth_item->rows()){
          $row->{deleted} = 1;
        }
        push @lost_items, $row;
    }
    return \@lost_items;
}

sub GetLostItem {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT li.*, itemlost, items.itemnumber as has_item from lost_items li left join items using(itemnumber) WHERE itemnumber=?");
    $sth->execute($itemnumber);
    my $lost_item = $sth->fetchrow_hashref;
    if( $lost_item && !$lost_item->{has_item}){
      $lost_item->{deleted} = 1;
    }
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


1;
