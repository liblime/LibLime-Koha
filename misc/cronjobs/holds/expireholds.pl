#!/usr/bin/perl
# run nightly -- remove holds that are later than waitingdate +
# ReservesMaxPickUpDelay from the reserves table.
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

=head1 NAME

expireholds.pl - cron script to remove expired holds from the reserves table

=head1 SYNOPSIS

./expireholds.pl

or, in crontab:
0 1 * * * $KOHA_CRON_DIR/holds/expireholds.pl

=head1 DESCRIPTION

This script simply removes holds in the reserves table that have expired.
Previously, the ReservesMaxPickUpDelay syspref was being used to display
that holds had expired, but they were not being deleted from the reserves
table.  This script corrects that problem.

=cut

use strict;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Dates;
my $today     = C4::Dates->new();
my $today_iso = $today->output('iso');

my $dbh = C4::Context->dbh;
my $query = "SELECT * FROM reserves
             WHERE expirationdate < ?";
my $sth = $dbh->prepare($query);
$sth->execute($today_iso);
while (my $expref = $sth->fetchrow_hashref) {
  my $insert_fields = '';
  my $value_fields = '';
  foreach my $column ('borrowernumber','reservedate','biblionumber','constrainttype','branchcode','notificationdate','reminderdate','cancellationdate','reservenotes','priority','found','itemnumber','waitingdate','expirationdate') {
    if (defined($expref->{$column})) {
      if (length($insert_fields)) {
        $insert_fields .= ",$column";
        $value_fields .= ",\'$expref->{$column}\'";
      }
      else {
        $insert_fields .= "$column";
        $value_fields .= "\'$expref->{$column}\'";
      }
    }
  }
  my $inssql = "INSERT INTO old_reserves ($insert_fields)
                VALUES ($value_fields)";
  my $sth2 = $dbh->prepare($inssql);
  $sth2->execute();
  my $delsql = "DELETE FROM reserves
                WHERE reservenumber = ?";
  $sth2 = $dbh->prepare($delsql);
  $sth2->execute($expref->{reservenumber});
}
$dbh->disconnect();
