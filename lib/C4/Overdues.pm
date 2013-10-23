package C4::Overdues;


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
use Date::Calc qw/Today Date_to_Days/;
use C4::Circulation;
use C4::Context;
use C4::Accounts;
use C4::Members;
use C4::Biblio;
use C4::Log; # logaction
use C4::Debug;
use Carp;


use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

BEGIN {
	# set the version for version checking
	$VERSION = 3.01;
	require Exporter;
	@ISA    = qw(Exporter);
	# subs to rename (and maybe merge some...)
	push @EXPORT, qw(
        &CalcFine
        &Getoverdues
        &checkoverdues
	);

    push @EXPORT_OK, qw(
        &AccrueFine
        &ApplyFine
        &DeleteAccruingFine
    );
}

=head1 NAME

C4::Circulation::Overdues - Koha module dealing with overdue items and related charges & statuses

=head1 SYNOPSIS

  use C4::Overdues;

=head1 DESCRIPTION

This module contains several functions for dealing with fines for
overdue items. It is primarily used by the 'misc/cronjobs/fines.pl' script.

=head1 FUNCTIONS

=head2 Getoverdues

  $overdues = Getoverdues( $option_hash );
  
=head3 optional parameters in C<$option_hash> :

=over 4

=item minimumdays => 1

default: 0.

=item maximumdays => 30

default: infinity.

Returns the list of all overdue items.

C<$overdues> is a reference-to-array. Each array element is a
reference-to-hash whose keys are the fields of the issues table
and select columns from the items table in the Koha database.

=cut

sub Getoverdues {
    my $params = shift;
    my $dbh = C4::Context->dbh;
    my $statement = "
   SELECT issues.*, items.itype as itemtype, items.homebranch, items.holdingbranch, items.barcode, items.itemlost
     FROM issues
LEFT JOIN items       USING (itemnumber)
    WHERE date_due < CURDATE()
";

    my @bind_parameters;

    if ( exists $params->{'minimumdays'} and exists $params->{'maximumdays'} ) {
        $statement .= ' AND TO_DAYS( NOW() )-TO_DAYS( date_due ) BETWEEN ? and ? ';
        push @bind_parameters, $params->{'minimumdays'}, $params->{'maximumdays'};
    } elsif ( exists $params->{'minimumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) > ? ';
        push @bind_parameters, $params->{'minimumdays'};
    } elsif ( exists $params->{'maximumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) < ? ';
        push @bind_parameters, $params->{'maximumdays'};
    }
    $statement .= 'ORDER BY borrowernumber ';
    my $sth = $dbh->prepare( $statement );
    $sth->execute( @bind_parameters );
    return $sth->fetchall_arrayref({});
}


=head2 checkoverdues

($count, $overdueitems) = checkoverdues($borrowernumber);

Returns a count and a list of overdueitems for a given borrowernumber

=cut

sub checkoverdues {
    my $borrowernumber = shift or return;
    my $sth = C4::Context->dbh->prepare(
        "SELECT issues.*, biblio.title, biblio.author FROM issues
         LEFT JOIN items       ON issues.itemnumber      = items.itemnumber
         LEFT JOIN biblio      ON items.biblionumber     = biblio.biblionumber
            WHERE issues.borrowernumber  = ?
            AND issues.date_due < CURDATE()"
    );
    $sth->execute($borrowernumber);
    my $results = $sth->fetchall_arrayref({});
    return ( scalar(@$results), $results);  # returning the count and the results is silly
}

=head2 CalcFine

  ($amount, $intervalcount, $intervaltotal) =
      &CalcFine($issue, $categorycode, $branch, $end_date, $calendar );

Calculates the fine for an overdue book.

The issuingrules table in the Koha database is a fine matrix, listing
the penalties for each type of patron for each type of item and each branch (e.g., the
standard fine for books might be $0.50, but $1.50 for DVDs, or staff
members might get a longer grace period).

This function calculates the number of fine_period intervals that have passed since the
item became overdue, and returns the amount due based on those calculations.

C<$issue> is an issue hashref (from GetItemIssue)

C<$categorycode> is the category code (string) of the patron who currently has
the book.

C<$branchcode> is the library (string) whose issuingrules govern this transaction.

C<$end_date> is a C4::Dates object
defining the ending date over which to determine the fine.

C<$calendar>, the controlling calendar for the transaction, may optionally be supplied.

C<&CalcFine> returns four values:

C<$amount> is the fine owed by the patron (see above).

C<$chargename> is the chargename field from the applicable record in
the categoryitem table, whatever that is.

C<$intervalcount> is the number of fine_period intervals between start and end dates,
adjusted for the policy's calendar and grace period.

C<$intervalcounttotal> is C<$intervalcount> without consideration of grace period.

=cut

sub CalcFine {
    my ( $issue, $bortype, $branchcode, $end_date, $cal ) = @_;
    croak "Too many args to CalcFine" if scalar(@_) > 5;
    $debug and warn sprintf("CalcFine(%s, %s, %s, %s, cal)",
            ($issue ? '{issue}' : 'UNDEF'),
            ($bortype    || 'UNDEF'),
            ($branchcode || 'UNDEF'),
            (  $end_date ? (  $end_date->output('iso') || 'Not a C4::Dates object') : 'UNDEF')
    );

    my $dbh = C4::Context->dbh;
    my $amount = Koha::Money->new();
    my ($daystocharge, $totaldays);
    my $start_date = C4::Dates->new($issue->{date_due},'iso');

    my $irule = C4::Circulation::GetIssuingRule($bortype, $$issue{itemtype}, $branchcode);
    if(C4::Context->preference('finesCalendar') eq 'noFinesWhenClosed') {
        $totaldays = $cal->daysBetween( $start_date, $end_date );
    } else {
        $totaldays = Date_to_Days(split('-',$end_date->output('iso'))) - Date_to_Days(split('-',$start_date->output('iso')));
    }
   # correct for grace period.
    my $days_minus_grace = 0;
#FIXME: this should be in calendar module.
    {
        no warnings 'uninitialized';
        $days_minus_grace = $totaldays - $irule->{'firstremind'};
        $daystocharge = (C4::Context->preference('FinesExcludeGracePeriod')) ? $days_minus_grace : $totaldays;
        if ($irule->{'chargeperiod'} > 0 && $days_minus_grace > 0 && $daystocharge > 0) {
            $amount = Koha::Money->new(int($daystocharge / $irule->{'chargeperiod'}) * $irule->{'fine'});

        }
        #else { a zero (or null)  chargeperiod means no charge.}
    }
    my $ismax = 0;
    my $sys_max = C4::Context->preference('MaxFine') || 0;
    my $rule_max = C4::Context->preference('UseGranularMaxFines') ? $irule->{max_fine} : 0;
    my $max_fine = $rule_max || $sys_max;
    if ($amount >= $max_fine) {
        $amount = Koha::Money->new($max_fine);
        $ismax = 1
    }

    $debug and warn sprintf("CalcFine returning (%s, %s, %s, %s)", $amount, $days_minus_grace, $daystocharge, $ismax);
    return ($amount, $daystocharge, $totaldays, $ismax);  # why return two interval counts ??
}



=head2 AccrueFine

  &AccrueFine($issue_id, $amount);

Updates the ESTIMATED overdue fine owed on an overdue item.

C<$amount> is the current amount owed by the patron (if they were to return it now).

C<&AccrueFine> updates the fees_accruing table, but does not actually charge a fine.
Rows in fees_accruing should cascade delete when the entry in the issues table is
deleted and copied to old_issues.

=cut


sub AccrueFine {
    my $issue_id = shift or return;
    my $amount   = shift;
    my $dbh = C4::Context->dbh;
    if($amount == 0){
        my $sth_del = $dbh->prepare('DELETE from fees_accruing where issue_id = ?');
        $sth_del->execute($issue_id);
    } else {
        $amount = Koha::Money->new($amount) unless(Check::ISA::obj($amount, 'Koha::Money'));
        my $sth_check = $dbh->prepare('select * from fees_accruing where issue_id = ?');
        $sth_check->execute($issue_id);
        my $update_query = ($sth_check->rows()) ?
                                "UPDATE fees_accruing SET amount = ? WHERE issue_id = ?" :
                                "INSERT INTO fees_accruing ( amount , issue_id ) VALUES ( ? , ? )";
        my $sth = $dbh->prepare($update_query);
        $sth->execute( $amount->value() , $issue_id );
    }
}

=head ApplyFine( $issue_hashref , $checkindate)

Applies an overdue fine associated with an issue record.
C<$checkindate> is a C4::Dates object representing the effective
checkin date to use in calculating the fine.


=cut

sub ApplyFine {
    my $issue = shift;
    my $checkindate = shift || C4::Dates->new();
    my $duedate = C4::Dates->new($issue->{'date_due'},'iso');
    my $borrower = C4::Members::GetMember($issue->{'borrowernumber'});  # Should be Memoized.
    my $item = C4::Items::GetItem($issue->{itemnumber});
    # $issue->{branchcode} holds the circControl branch.

    return if($duedate->output('iso') gt $checkindate->output('iso')); # or it's not overdue, right?
    my $control = C4::Context->preference('CircControl');
    my $branchcode = ($control eq 'ItemHomeLibrary') ? $item->{homebranch} :
                     ($control eq 'PatronLibrary'  ) ? $borrower->{branchcode} :
                                                       $issue->{branchcode} ;
    # In final case, CircControl must be PickupLibrary. (branchcode comes from issues table here).
    my $calendar = C4::Calendar->new(branchcode => $branchcode);
    #my ($amount,$chargeintervals)= CalcFine($issue, $borrower->{'categorycode'}, $branchcode, $checkindate, $calendar);
    my ($amount, $days_minus_grace, $daystocharge, $ismax)= CalcFine($issue, $borrower->{categorycode}, $branchcode, $checkindate, $calendar);
    if($amount){
        my $biblio = GetBiblioFromItemNumber($issue->{itemnumber});
    
        # begin transaction
        my %new_fee = (
                        borrowernumber => $issue->{borrowernumber},
                        itemnumber  => $issue->{itemnumber},
                        amount      => $amount,
                        accounttype => 'FINE',
                        description => "Overdue: $biblio->{'title'}",
                        );
        my $fee_rowid = C4::Accounts::CreateFee( \%new_fee );
    }
}

=head DeleteAccruingFine( $issue_id )

Removes Accruing fine record in fees_accruing table.

=cut

sub DeleteAccruingFine {
    my $issue_id = shift;
    my $sth_del = C4::Context->dbh()->prepare('delete from fees_accruing where issue_id = ?');
    $sth_del->execute($issue_id);
}

=head ClearAccruingFines( )

Truncates fees_accruing table.

=cut

sub ClearAccruingFines {
    C4::Context->dbh()->do('TRUNCATE fees_accruing');
}


=head2 GetOverduesForBranch

Sql request for display all information for branchoverdues.pl
This filters overdue items by whether or not the patron has been notified.
The means of entering the notification data is not currently in branchoverdues.pl. (3/2009).
This sub also only returns overdue items with fines.
2 possibilities : with or without location .
display is filtered by branch

FIXME: This function should be renamed.

=cut

sub GetOverduesForBranch {
    my ( $branch, $location ) = @_;
    my $dbh = C4::Context->dbh;
    my $select = " SELECT 
            borrowers.borrowernumber,
            borrowers.surname,
            borrowers.firstname,
            borrowers.phone,
            borrowers.email,
               biblio.title,
               biblio.biblionumber,
               issues.date_due,
               issues.branchcode,
             branches.branchname,
                items.barcode,
                items.itemcallnumber,
                items.location,
                items.itemnumber,
            itemtypes.description,
         fees_accruing.amount
    FROM  fees_accruing
    LEFT JOIN issues      ON    issues.id = issue_id
    LEFT JOIN borrowers   ON borrowers.borrowernumber = issues.borrowernumber
    LEFT JOIN items       ON     items.itemnumber     = issues.itemnumber
    LEFT JOIN biblio      ON      biblio.biblionumber =  items.biblionumber
    LEFT JOIN biblioitems ON biblioitems.biblioitemnumber = items.biblioitemnumber
    LEFT JOIN itemtypes   ON items.itype       = itemtypes.itemtype
    LEFT JOIN branches    ON  branches.branchcode     = issues.branchcode
    WHERE ( issues.branchcode = ? )
      AND ( issues.date_due  <= NOW())
    ";
    my @getoverdues;
    my $i = 0;
    my $sth;
    if ($location) {
        $sth = $dbh->prepare("$select AND items.location = ? ORDER BY borrowers.surname, borrowers.firstname");
        $sth->execute($branch, $location);
    } else {
        $sth = $dbh->prepare("$select ORDER BY borrowers.surname, borrowers.firstname");
        $sth->execute($branch);
    }
    while ( my $data = $sth->fetchrow_hashref ) {
    #check if the document has already been notified
  #FIXME: that's gone now.
  #      my $countnotify = CheckItemNotify($data->{'notify_id'}, $data->{'notify_level'}, $data->{'itemnumber'});
  #      if ($countnotify eq '0') {
            $getoverdues[$i] = $data;
            $i++;
   #     }
    }
    return (@getoverdues); 
}


1;
__END__

=head1 AUTHOR

Koha Developement team <info@koha.org>

=cut
