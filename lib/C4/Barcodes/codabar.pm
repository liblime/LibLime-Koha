package C4::Barcodes::codabar;

# Copyright 2010 LibLime
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

use Carp;

use Koha;
use C4::Context;
use C4::Debug;
use C4::Dates;

use vars qw($VERSION @ISA $width);

# $width is depracated... it is 14
# but I am keeping it here to maintain standardization w/ C4::Barcodes and ::x -hQ
BEGIN {
   $VERSION = 0.01;
   @ISA = qw(C4::Barcodes);
	$width = 14;
}

# type is 'patron' or 'item'
# see C4::Barcodes::validate()
#
# returns the max sequence number for the given 'type',
# which is the table key column, viz.
#     borrowers.borrowernumber
#     items.itemnumber
#
# increment this number yourself
#
sub db_max {
	my $type = shift;
   my $table = 'items';
   my $keycol= 'itemnumber';
   if ($type eq 'patron') {
      $table  = 'borrowers';
      $keycol = 'borrowernumber';
   }
   my $dbh = C4::Context->dbh;

   # known race condition on max() for a db read
   my $sth = $dbh->prepare("SELECT MAX($keycol) FROM $table") || die $dbh->errstr();
   $sth->execute() || die $dbh->errstr();
   my($max) = ($sth->fetchrow_array)[0];
   return $max;
}

sub initial () {
	my $self = shift;
   return 0;
}

sub width ($;$) {
	my $self = shift;
	(@_) and $width = shift;	# hitting the class variable.
	return $width;
}

# returns empty barcode and an errStr on error.
#
#  my($barcode,$errStr) = C4::Barcodes::codabar::autogen_borrower($branchcode);
#  unless ($barcode) { push @errs, $errStr }
#
sub autogen_borrower { return _autogen('borrower',shift) }
sub autogen_item     { return _autogen('item'    ,shift) }


#  2 9 0 7 8 1 2 3 4 5 6 7 8 8
#  ^ <-----> <-------------> ^
#  |    |          |         \-- check digit
#  |    |          \-- sequence number, from borrowers.borrowernumber
#  |    \-- 9078=library branch prefix
#  \-- barcode type, 2=borrower|3=item
#
# returns 0|1, errorStr if 0
# boolean $dupecheck is optional.  set to 1 if you want to check against any other
#  barcode in the database as a duplicate
#
#     my($errStr) = C4::Barcodes::codabar::validate(
#        $barcode,
#        'patron',         # or 'item'
#        $branchcode
#        (,$dupecheck)     # optional
#     );
#     push @errs,{msg=>$errStr} unless $ok;
sub validate
{
   my($barcode,$barcodetype,$branchcode,$dupecheck) = @_;
   $barcodetype ||= 'patron'; # patron|item
   unless (grep /^$barcodetype$/, qw(patron item patron2 item2)) {
      return 0,"Acceptable barcodetype: 'patron' or 'item'";
   }
# Also support barcodetypes item2, patron2.
# item2 has additional check of barcode vs patron cardnumber.
# patron2 has additional check of cardnumber vs item barcode.


   my $basetype = ( $barcodetype eq "item" or $barcodetype eq "item2")
                ? 'item' : 'patron';

   # the 'other' object (patron vs item) has dibs on the checked barcode.
   my $otherdibs = ($barcodetype eq "item2" or $barcodetype eq "patron2")
                 ? 1 : 0;

   ## get prefix from db
   my $sth;
   my $dbh = C4::Context->dbh;
   my $dbPrefix = '';
   $sth = $dbh->prepare("SELECT ${basetype}barcodeprefix FROM branches
      WHERE branchcode = ?") || die $dbh->errstr();
   $sth->execute($branchcode) || die $dbh->errstr();
   $dbPrefix = ($sth->fetchrow_array())[0];
   ## soft return: if it's not set, don't do checking
   return 1 unless $dbPrefix;

   my $len = C4::Context->preference("${basetype}barcodelength");
   if (length($barcode) != $len) {
      return 0,"Expected barcode length of $len characters";
   }
   if ($barcode =~ /\D/) {
      return 0,"Barcode type of 'codabar' must contain all digits";
   }
   my($type,$infix,$seq,$checkdigit) = $barcode =~ /^(\d)(\d{4})(\d{8})(\d)$/;
   if ("$type$infix" != $dbPrefix) {
      return 0,"Invalid prefix ($type$infix), expected $dbPrefix";
   }

   # dupecheck
   if ($dupecheck) {
      my ($sql, $err);
      if ($basetype eq 'patron') {
         $sql = "SELECT 1 FROM borrowers WHERE cardnumber = ?";
         $err = "Duplicate patron cardnumber.";
      }
      else { # item
         $sql = "SELECT 1 FROM items WHERE barcode = ?";
         $err = "Duplicate item barcode.";
      }
      $sth = $dbh->prepare($sql) || die $dbh->errstr();
      $sth->execute($barcode) || die $dbh->errstr();
      my($dupe) = ($sth->fetchrow_array)[0];
      return 0,$err if $dupe;
   }
   if ($otherdibs) {
      my ($sql,$err);
      if ($basetype eq 'patron') {
         $sql = "SELECT 1 FROM items WHERE barcode = ?";
         $err = "A catalogued item barcode already uses this cardnumber.";
      }
      else { #basetype item2
         $sql = "SELECT 1 FROM borrowers WHERE cardnumber = ?";
         $err = "A patron cardnumber already uses this barcode.";
      }
      $sth = $dbh->prepare($sql) || die $dbh->errstr();
      $sth->execute($barcode) || die $dbh->errstr();
      my($hit) = ($sth->fetchrow_array)[0];
      return 0, $err if $hit;
    }

   # digit 14: check digit
   # start with the total set to zero and scan the 13 digits from left to right.
   # if the digit is in an even-numbered position (2,4,6,..) add it to the total.
   # if the digit is an odd-numbered position (1,3,5,..) multiply the digit by 2.
   #     if the product is equal to or greater than 10, subtract 9 from the 
   #     product.
   #     then add the product to the total.
   #  after all the digits have been processed, divide the total by 10 and take
   #     the remainder.
   #  if the remainder = 0, that is the check digit.
   #  if the remainder is not zero, the check digit is 10 minus the remainder.
   my($bc13) = $barcode =~ /^(\d{13})/;
   my $remainder = _remainder($bc13);
   if (($remainder==0) && ($checkdigit==0)) {
      return 1;
   }
   elsif ($remainder == $checkdigit) {
      return 1;
   }
   else {
      if ((10-$remainder) != $checkdigit) {
         return 0,"Barcode failed checksum, remainder=$remainder, given=$checkdigit";
      }
   }
   return 1;
}


# these methods are not relevant to the use of codabar checksum
sub parse         { return undef }
sub process_head  { return undef } 

sub new_object {
	my $class = shift;
	my $type = ref($class) || $class;
	my $self = $type->default_self('annual');
	return bless $self, $type;
}

sub _remainder
{
   my $bc13 = shift;
   my $total = 0;
   for my $i(1..13) {
      my $digit = substr($bc13,$i-1,1);
      if ($i%2) { # odd position
         my $product = $digit*2;
         if ($product >= 10) {
            $product -= 9;
         }
         $total += $product;

      }
      else { # even
         $total += $digit;
      }
   }
   my $remainder = $total%10;
   return $remainder;
}

# returns empty barcode and an errStr on error.
#
#  my($barcode,$errStr) = C4::Barcodes::codabar::autogen_borrower($branchcode);
#  unless ($barcode) { push @errs, $errStr }
#
sub _autogen
{
   my($type,$branchcode) = @_;
   return undef,'branchcode is required' unless $branchcode;
   my $dbh = C4::Context->dbh;
   my $init= $type eq 'borrower'?2:3; #  prefix
   my $sel = $type eq 'borrower'?'patron':'item';
   my $sth = $dbh->prepare("
      SELECT ${sel}barcodeprefix
      FROM   branches
      WHERE  branchcode = ?") || die $dbh->errstr();
   $sth->execute($branchcode) || die $dbh->errstr();
   my($prefix) = ($sth->fetchrow_array)[0];
   return undef,'No ${sel}barcodeprefix set in database' unless $prefix;
   my $seq = sprintf("%08d",db_max('item')+1); # known race condition
   my $checkdigit = _remainder("$init$prefix$seq");
   my $barcode = "$init$prefix$seq$checkdigit";
   return $barcode;
}

1;
__END__
