package C4::Stats;


# Copyright 2000-2002 Katipo Communications
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
require Exporter;
use Koha;
use C4::Context;
use C4::Debug;
use vars qw($VERSION @ISA @EXPORT);

our $debug;

BEGIN {
	# set the version for version checking
	$VERSION = 3.01;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&UpdateStats
		&UpdateReserveCancelledStats
		&TotalPaid
	);
}


=head1 NAME

C4::Stats - Update Koha statistics (log)

=head1 SYNOPSIS

  use C4::Stats;

=head1 DESCRIPTION

The C<&UpdateStats> function adds an entry to the statistics table in
the Koha database, which acts as an activity log.

=head1 FUNCTIONS

=over 2

=item UpdateStats

  &UpdateStats($branch, $type, $value, $other, $itemnumber,
               $itemtype, $borrowernumber);

Adds a line to the statistics table of the Koha database. In effect,
it logs an event.

C<$branch>, C<$type>, C<$value>, C<$other>, C<$itemnumber>,
C<$itemtype>, and C<$borrowernumber> correspond to the fields of the
statistics table in the Koha database.

=cut

#'

sub UpdateStats {
    my (
        $branch,   $type,
        $amount,   $other,          $itemnum,
        $itemtype, $borrowernumber, $accountno
        )
        = @_;

    my @bind;
    my $query = q{
        INSERT INTO statistics
        (datetime, branch, type, value,
        other, itemnumber, itemtype, borrowernumber, proccode)
        VALUES (now(),?,?,?,?,?,?,?,?)
        };

    if (C4::Context->preference('SplitStatistics')) {
        # Add two entries, one with a null patron, and
        # the other with a null item
        $query .= ',(now(),?,?,?,?,?,?,?,?)';

        @bind = ($branch, $type."_item", $amount, $other, $itemnum,
        $itemtype, undef, undef,
        $branch, $type."_patron", $amount, $other, undef,
        undef, $borrowernumber, $accountno);
    }
    else {
        @bind = ($branch, $type, $amount, $other, $itemnum,
        $itemtype, $borrowernumber, $accountno);
    }
    C4::Context->dbh->do($query, undef, @bind);

    return undef;
}

sub UpdateReserveCancelledStats {

    #module to insert stats data into stats table
    my (
        $branch,         $type,
        $amount,   $other,          $itemnum,
        $itemtype, $borrowernumber, $accountno, $modusernumber
      )
      = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "INSERT INTO statistics
        (datetime, branch, type, value,
         other, itemnumber, itemtype, borrowernumber, proccode, usercode)
         VALUES (now(),?,?,?,?,?,?,?,?,?)"
    );
    $sth->execute(
        $branch,    $type,    $amount,
        $other,     $itemnum, $itemtype, $borrowernumber,
	$accountno, $modusernumber
    );
}

# Otherwise, it'd need a POD.
sub TotalPaid {
    my ( $time, $time2, $spreadsheet ) = @_;
    $time2 = $time unless $time2;
    my $dbh   = C4::Context->dbh;
    my $query = "SELECT * FROM statistics 
  LEFT JOIN borrowers ON statistics.borrowernumber= borrowers.borrowernumber
  WHERE (statistics.type='payment' OR statistics.type='writeoff') ";
    if ( $time eq 'today' ) {
        $query .= " AND datetime = now()";
    } else {
        $query .= " AND datetime > '$time'";    # FIXME: use placeholders
    }
    if ( $time2 ne '' ) {
        $query .= " AND datetime < '$time2'";   # FIXME: use placeholders
    }
    if ($spreadsheet) {
        $query .= " ORDER BY branch, type";
    }
    $debug and warn "TotalPaid query: $query";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    return @{$sth->fetchall_arrayref({})};
}

sub GetPreviousCardnumbers {
  my ( $borrowernumber ) = @_;
  my $dbh = C4::Context->dbh;
  
  my $member = C4::Members::GetMember( $borrowernumber );
  my $cardnumber = $member->{'cardnumber'};
  
  my $query = "SELECT DISTINCT(other) AS previous_cardnumber, DATE_FORMAT( datetime, '%m/%e/%Y') as previous_cardnumber_date FROM statistics WHERE type = 'card_replaced' AND borrowernumber = ? AND other != ? AND other !='' ";
  my $sth = $dbh->prepare( $query );
  $sth->execute( $borrowernumber, $cardnumber );

  my @results;
  while ( my $data = $sth->fetchrow_hashref ) {
    push( @results, $data );
  }
  $sth->finish;

  return @results;  
}
                          
1;
__END__

=back

=head1 AUTHOR

Koha Developement team <info@koha.org>

=cut

