package C4::ItemType;

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

our $AUTOLOAD;




=head1 NAME

C4::ItemType - objects from the itemtypes table

=head1 SYNOPSIS

    use C4::ItemType;
    my @itemtypes = C4::ItemType->all;
    print join("\n", map { $_->description } @itemtypes), "\n";

=head1 DESCRIPTION

Objects of this class represent a row in the C<itemtypes> table.

Currently, the bare minimum for using this as a read-only data source has
been implemented.  The API was designed to make it easy to transition to
an ORM later on.

=head1 API

=head2 Class Methods

=cut

=head3 C4::ItemType->new(\%opts)

Given a hashref, a new (in-memory) C4::ItemType object will be instantiated.
The database is not touched.

=cut

sub new {
    my ($class, $opts) = @_;
    bless $opts => $class;
}

## check to see if this itemtype is used.
## returns a total number
sub checkUsed
{
   my($s,$type) = @_;
   my $total = 0;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('
      SELECT COUNT(*) as total
        FROM biblioitems
       WHERE itemtype = ?');
   $sth->execute($type);
   $total += $sth->fetchrow_hashref->{'total'};
   return $total;
}

sub search
{
   my($s,$str,$type) = @_;
   my $dbh = C4::Context->dbh;
   $str  ||= '';
   $str    =~ s/\'/\\\'/g;
   my @d   = split(' ',$str);
   my $sth = $dbh->prepare('
      SELECT * FROM itemtypes
       WHERE (description LIKE ?)
    ORDER BY itemtype');
   $d[0] //= '';
   $sth->execute("$d[0]%");
   return $sth->fetchall_arrayref({});
}

## get one row by itemtype
sub get
{
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('SELECT * FROM itemtypes 
      WHERE UCASE(itemtype)=UCASE(?)');
   $sth->execute($_[1]);
   return $sth->fetchrow_hashref() // {};
}

sub del
{
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('DELETE FROM itemtypes WHERE UCASE(itemtype)=UCASE(?)');
   $sth->execute($_[1]);
   return 1;
}

sub save
{
   my($s,%g) = @_;
   my $dbh = C4::Context->dbh;
   my $sth;

      #col    required 0=str,1=bool,2=money,3=int
   my @f = ( 
      ['itemtype'         ,1, 0],
      ['description'      ,0, 0],
      ['renewalsallowed'  ,1, 3],
      ['rentalcharge'     ,0, 2],
      ['replacement_price',0, 2],
      ['notforloan'       ,1, 1],
      ['imageurl'         ,0, 0],
      ['summary'          ,0, 0],
      ['reservefee'       ,0, 2],
      ['notforhold'       ,1, 1]
   );
   $sth = $dbh->prepare('SELECT 1 FROM itemtypes WHERE itemtype=?');
   $sth->execute($g{itemtype});
   my $update = ($sth->fetchrow_array)[0] // 0;
   
   my %new = ();
   foreach(@f) {
      if (defined $g{$$_[0]}) { $new{$$_[0]} = $g{$$_[0]} }
      else                    { $new{$$_[0]} = undef      }
      if ($$_[2]==1) {
         $new{$$_[0]} = $g{$$_[0]}? 1:0;
      }
      elsif ($$_[2]==3) {
         $new{$$_[0]} = $g{$$_[0]};
         $new{$$_[0]} =~ s/\D//g;
      }
      else {
         $new{$$_[0]} = $g{$$_[0]} || '';
      }
   }
   
   my $sql = '';
   my @vals= ();
   if ($update) {
      my $itemtype = $new{itemtype};
      delete($new{itemtype});
      $sql = sprintf("UPDATE itemtypes SET %s WHERE itemtype=?",
         join(',',map{"$_=?"}keys %new)
      );
      @vals = (values %new, $itemtype);
   }
   else {
      $sql = sprintf("INSERT INTO itemtypes(%s) VALUES(%s)",
         join(',',keys %new),
         join(',',map{'?'}keys %new)
      );
      @vals = values %new;
   }
   $sth = $dbh->prepare($sql);
   $sth->execute(@vals);
   return;
}



=head3 C4::ItemType->all

This returns all the itemtypes as objects.  By default they're ordered by
C<description>.

=cut

sub all {
    my ($class) = @_;
    my $dbh = C4::Context->dbh;
    return    map { $class->new($_) }    @{$dbh->selectall_arrayref(
        # The itemtypes table is small enough for
        # `SELECT *` to be harmless.
        "SELECT * FROM itemtypes ORDER BY description",
        { Slice => {} },
    )};
}


=head2 Object Methods

These are read-only accessors for attributes of a C4::ItemType object.

=head3 $itemtype->itemtype

=head3 $itemtype->description

=head3 $itemtype->renewalsallowed

=head3 $itemtype->rentalcharge

=head3 $itemtype->notforloan

=head3 $itemtype->imageurl

=head3 $itemtype->summary

=cut

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*://;
    if (exists $self->{$attr}) {
        return $self->{$attr};
    } else {
        return undef;
    }
}

sub DESTROY { }



# ack itemtypes | grep '\.pm' | awk '{ print $1 }' | sed 's/:.*$//' | sort | uniq | sed -e 's,/,::,g' -e 's/\.pm//' -e 's/^/L<C4::/' -e 's/$/>,/'

=head1 SEE ALSO

The following modules make reference to the C<itemtypes> table.

L<C4::Biblio>,
L<C4::Circulation>,
L<C4::Context>,
L<C4::Items>,
L<C4::Koha>,
L<C4::Labels>,
L<C4::Overdues>,
L<C4::Reserves>,
L<C4::Search>,
L<C4::VirtualShelves::Page>,
L<C4::VirtualShelves>,
L<C4::XSLT>



=head1 AUTHOR

John Beppu <john.beppu@liblime.com>

=cut

1;
