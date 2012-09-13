package C4::Reports;

# Copyright 2007 Liblime Ltd
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
use CGI;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Koha;
use C4::Context;
use C4::Debug;

BEGIN {
    # set the version for version checking
    $VERSION = 0.13;
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        AddCondition
        GetDelimiterChoices
    );
}

=head1 NAME
   
C4::Reports - Module for generating reports 

=head1 DESCRIPTION

This module contains functions common to reports.

=head1 EXPORTED FUNCTIONS

=head2 GetDelimiterChoices

=over 4

my $delims = GetDelimiterChoices;

=back

This will return a list of all the available delimiters.

=cut

sub GetDelimiterChoices {
    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare("
      SELECT options, value
      FROM systempreferences
      WHERE variable = 'delimiter'
    ");

    $sth->execute();

    my ($choices, $default) = $sth->fetchrow;
    my @dels = split /\|/, $choices;

    return CGI::scrolling_list(
                -name     => 'sep',
                -id       => 'sep',
                -default  => $default,
                -values   => \@dels,
                -size     => 1,
                -multiple => 0 );
}

=head2 AddCondition

=over 4

($current_sql,  @query_params) = AddCondition( $current_sql, $column, $value );
$current_sql = AddCondition( $current_sql, $column, $value, 0 );

=back

Given some already built SQL (which should be in the middle of the WHERE
clause), a column and its possible values, this function will see if the passed
string contains multiple choices, and do one of two things:

* Multiple choices ($value is something like 'CPL,FPL' or [ 'CPL', 'FPL' ]):
  Add 'AND $column IN (?, ?)'
* A single choice ($value is something like '*stiff*'):
  Add 'AND $column LIKE ?'

If the last parameter ($use_params) is 1 (the default), placeholders will be
inserted into the SQL, and a list of parameters to add to what is sent to
$sth->execute will be returned. Otherwise, the values will be quoted and
inserted into the SQL directly.

=cut

sub AddCondition {
    my ( $current_sql, $column, $value, $use_params ) = @_;
    my $dbh = C4::Context->dbh;
    $use_params = 1 if ( !defined( $use_params ) );

    my @values = ref $value eq 'ARRAY' ? @$value : split /,/, $value;

    # The below allows simple columns or functions, like left(zipcode, 3)
    die "Invalid column $column" if ( $column !~ /^([A-Za-z0-9_.]+|[A-Za-z0-9_]+\([A-Za-z0-9,'"_. -]+\))$/ );

    if ( scalar( @values ) > 1 ) {
        $current_sql .= " AND $column IN (" . join( ', ', ( $use_params ? ( '?' ) x scalar( @values ) : map { $dbh->quote( $_ ) } @values ) ) . ")";
    } else {
        $values[0] =~ s/\*/%/g;
        $current_sql .= " AND $column LIKE " . ( $use_params ? '?' : $dbh->quote( $values[0] ) );
    }

    if ( $use_params ) {
        return ( $current_sql, @values );
    } else {
        return $current_sql;
    }
}

## not exported.
sub HoldsShelf
{
   my %g   = @_;
   my $dbh = C4::Context->dbh;
   my $lim = '';
   my @lims;
   if ($g{branchcode}) { 
      $lim .= " AND old_reserves.branchcode = ?"; 
      push @lims, $g{branchcode}; 
   }
  
   my $sql = qq|
      SELECT old_reserves.reservenumber,
             old_reserves.reservedate,
             old_reserves.waitingdate,
             old_reserves.cancellationdate,
             old_reserves.expirationdate,
             old_reserves.biblionumber,
             old_reserves.itemnumber,
             items.barcode,
             items.ccode,
             items.itemcallnumber,
             borrowers.borrowernumber,
             borrowers.surname,
             borrowers.firstname,
             borrowers.cardnumber,
             biblio.title
        FROM old_reserves
   LEFT JOIN biblio    ON (old_reserves.biblionumber   = biblio.biblionumber)
   LEFT JOIN borrowers ON (old_reserves.borrowernumber = borrowers.borrowernumber)
   LEFT JOIN items     ON (old_reserves.itemnumber     = items.itemnumber)
       WHERE old_reserves.found = 'W' $lim
         AND (old_reserves.expirationdate <= NOW() OR old_reserves.cancellationdate IS NOT NULL)
   |;
   my $sth = $dbh->prepare($sql);
   $sth->execute(@lims);
   my @all = ();
   while(my $row = $sth->fetchrow_hashref()) {
      if (my $marc = C4::Biblio::GetMarcBiblio($$row{biblionumber})) {
         foreach(qw(b h n p)) {
            $$row{"marc_245_$_"} = $marc->subfield('245',$_) // '';
         }
      }
      push @all, $row; 
   }
   return wantarray ? @all : \@all;
}

sub _prepSqlHolds
{
   my %g = @_;
   my $f = []; # 2-dimensional array of subclauses after WHERE and params
   if ($g{patron}) {
      $g{patron} =~ s/['"]//g;
      push @$f, ["LCASE(borrowers.surname) LIKE(LCASE('%$g{patron}%'))",'_undef'];
   }
   my %d = ( 
      'fromdate'     , 'reservedate >='      ,
      'todate'       , 'reservedate <='      ,
      'holdexpdate'  , 'expirationdate ='    ,
      'holdcandate'  , 'cancellationdate ='  ,
   );
   foreach(keys %d) {
      next unless exists $g{$_};
      if ($g{$_} =~ /^(\d\d)\/(\d\d)\/(\d{4})$/) {
         push @$f, ["old_reserves.$d{$_} ?","$3-$1-$2"];
      }
      elsif ($g{$_}) {
         die "Malformed $_, expected mm/dd/yyyy";
      }
   }
   if ($g{branchcode}) {
      push @$f, ['old_reserves.branchcode = ?',$g{branchcode}];
   }
   return $f;
}

sub _getSqlHolds
{
   my $f      = shift;
   my $dbh    = C4::Context->dbh;
   my @vals   = ();
   my %res    = ();
   foreach(@$f) { if ($$_[1] ne '_undef') { push @vals, $$_[1] } }
   my $sth = $dbh->prepare(sprintf(qq|
      SELECT biblio.title,
             borrowers.surname,
             borrowers.firstname,
             borrowers.borrowernumber,
             borrowers.cardnumber,
             old_reserves.reservenumber,
             old_reserves.biblionumber,
             old_reserves.itemnumber,
             old_reserves.reservedate,
             old_reserves.cancellationdate,
             old_reserves.expirationdate,
             old_reserves.found,
             old_reserves.priority,
             branches.branchname
        FROM old_reserves 
   LEFT JOIN borrowers ON (old_reserves.borrowernumber = borrowers.borrowernumber) 
   LEFT JOIN biblio    ON (old_reserves.biblionumber   = biblio.biblionumber) 
   LEFT JOIN branches  ON (old_reserves.branchcode     = branches.branchcode) 
            %s
    ORDER BY borrowers.surname, old_reserves.reservedate|,
         @$f? sprintf("WHERE %s",join(' AND ',map{$$_[0]}@$f)):''
      )
   );
   $sth->execute(@vals);
   my @all;
   while(my $row = $sth->fetchrow_hashref()) { push @all, $row; }
   return \@all // [];
}

# not exported.
sub ExpiredHolds
{
   my %g = @_;
   my $f = _prepSqlHolds(%g);
   push @$f, ['old_reserves.cancellationdate IS NULL','_undef'];
   push @$f, ["(old_reserves.found != 'F' OR old_reserves.found IS NULL)",'_undef'];
   # Any expired holds should actually have found IN ('W','E').  Leaving this as is, since this was not true before 2012/08.
   return _getSqlHolds($f);
}

# not exported.
sub CancelledHolds
{
   my %g = @_;
   my $f = _prepSqlHolds(%g);
   push @$f, ['old_reserves.cancellationdate IS NOT NULL','_undef'];
   return _getSqlHolds($f);
}

1;
__END__

=head1 AUTHOR

Jesse Weaver <jesse.weaver@liblime.com>

=cut
