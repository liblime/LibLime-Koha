package C4::Members;

# Copyright 2000-2003 Katipo Communications
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

use Carp qw(carp cluck croak confess);

use Koha;
use C4::Context;
use C4::Dates qw(format_date_in_iso);
use Digest::MD5 qw(md5_base64);
use Date::Calc qw/Today Add_Delta_YM/;
use C4::Log; # logaction
use C4::Branch qw(GetBranchDetail);
use C4::Overdues;
use C4::Reserves;
use C4::Accounts;
use C4::Biblio;
use C4::Items;
use C4::Koha qw( GetAuthValCode );
use C4::Auth qw();

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
	$VERSION = 3.02;
	$debug = $ENV{DEBUG} || 0;
	require Exporter;
	@ISA = qw(Exporter);
	#Get data
	push @EXPORT, qw(
		&SearchMember 
		&SearchMemberAdvanced
		&SearchMemberBySQL
		&GetMemberDetails
		&GetMember

		&GetGuarantees 

		&GetMemberIssuesAndFines
		&GetPendingIssues
		&GetAllIssues
        &GetEarliestDueDate

		&get_institutions 
		&getzipnamecity 
		&getidcity

                &GetFirstValidEmailAddress

		&GetAge 
		&GetCities 
		&GetRoadTypes 
		&GetRoadTypeDetails 
		&GetSortDetails
		&GetTitles

		&GetPatronImage
		&PutPatronImage
		&RmPatronImage

		&GetBorNotifyAcctRecord
        &GetLostStats
        &GetNotifiedMembers

		&GetborCatFromCatType 
		&GetBorrowercategory
		&GetBorrowercategoryList

		&GetBorrowersWhoHaveNotBorrowedSince
		&GetBorrowersWhoHaveNeverBorrowed
		&GetBorrowersWithIssuesHistoryOlderThan

		&GetExpiryDate

		&AddMessage
		&DeleteMessage
		&GetMessages
		&GetMessagesCount
                &GetMemberRevisions

                &SetDisableReadingHistory
	);

	#Modify data
	push @EXPORT, qw(
		&ModMember
		&changepassword
        &MarkMemberReported
	);

	#Delete data
	push @EXPORT, qw(
		&DelMember
	);

	#Insert data
	push @EXPORT, qw(
		&AddMember
		&add_member_orgs
		&MoveMemberToDeleted
		&ExtendMemberSubscriptionTo
	);

	#Check data
    push @EXPORT, qw(
        &checkuniquemember
        &checkuserpassword
        &Check_Userid
        &Generate_Userid
        &fixEthnicity
        &ethnicitycategories
        &fixup_cardnumber
        &checkcardnumber
    );
}

=head1 NAME

C4::Members - Perl Module containing convenience functions for member handling

=head1 SYNOPSIS

use C4::Members;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting members/patrons/borrowers 

=head1 FUNCTIONS

=over 2

=item SearchMember

  ($count, $borrowers) = &SearchMember($searchstring, $orderby, $type, $category_type);

=back

Looks up patrons (borrowers) by name.

C<$type> is now used to determine type of search.
if $type is "simple", search is performed on the first letter of the
surname only.

$category_type is used to get a specified type of user. 
(mainly adults when creating a child.)

C<$searchstring> is a space-separated list of search terms. Each term
must match the beginning a borrower's surname, first name, other
name, or initials.

C<&SearchMember> returns a two-element list. C<$borrowers> is a
reference-to-array; each element is a reference-to-hash, whose keys
are the fields of the C<borrowers> table in the Koha database.
C<$count> is the number of elements in C<$borrowers>.

=cut

sub _constrain_sql_by_branchcategory {
    my ($query, @bind) = @_;

    if (   C4::Branch::CategoryTypeIsUsed('patrons')
        && $ENV{REQUEST_METHOD} # need a nicer way to do this, but check if we're command line vs. CGI
        && !C4::Auth::haspermission(undef, {superlibrarian => 1})
        )
    {
        my $mybranch = (C4::Context->userenv) ? C4::Context->userenv->{branch} : undef;
        confess 'Unable to determine selected branch' if not $mybranch;
        my @sibling_branchcodes = C4::Branch::GetSiblingBranchesOfType($mybranch, 'patrons');
        my $clause = sprintf ' borrowers.branchcode IN (%s) ', join(',', map {'?'} @sibling_branchcodes) ;

        # This doesn't work if we don't have a WHERE clause
        $query =~ s/WHERE/WHERE $clause AND /;
        unshift @bind, @sibling_branchcodes;
    }

    return ($query, @bind);
}

sub SearchMember {
    my ($searchstring, $orderby, $type, $category_type, $limits) = @_;
    $orderby ||= 'surname';
    $limits //= {offset => 0, limit => C4::Context->preference('PatronsPerPage')};

    # FIXME: find where in members.pl this function is being called a second time with no args
    return (0, []) if (!$searchstring);

    my $dbh   = C4::Context->dbh;
    my $sth;
    my @bind;
    my $query = q{
        SELECT SQL_CALC_FOUND_ROWS *
        FROM borrowers
        LEFT JOIN categories
          ON borrowers.categorycode=categories.categorycode
        WHERE 1
      };

    ($query, @bind) = _constrain_sql_by_branchcategory($query);

    # this is used by circulation everytime a new borrowers cardnumber is scanned
    # so we can check an exact match first, if that works return, otherwise do the rest
    if (($searchstring !~ /\D/) && C4::Context->preference('patronbarcodelength')) {
        ## this handles the edge case of multiple barcodes with same right-hand 
        ## significant digits, different branch prefixes.
        my @in = @{_prefix_cardnum_multibranch($searchstring)};
        $sth = $dbh->prepare(
            sprintf("$query AND cardnumber IN (%s) LIMIT 1",
                join(',', map {'?'} @in)
            ));
        $sth->execute(@bind, @in);
    }
    else {
        $sth = $dbh->prepare("$query AND cardnumber=? LIMIT 1");
        $sth->execute(@bind, $searchstring);
    }
    
    my $data = $sth->fetchrow_hashref();
    if ($data) {
        return (1, [$data]);
    }

    if ($category_type) {
        $query .= ' AND category_type = ? ';
        push @bind, $category_type;
    }

    # simple search for one letter only
    if ($type ~~ 'simple') {
        $query .= ' AND (surname LIKE ? OR cardnumber LIKE ?) ';
        push @bind, ("$searchstring%","$searchstring");
    }
    # advanced search looking in surname, firstname, othernames, and initials
    else {
        my @data  = split(' ', $searchstring);
        my $count = @data;
        $query .= ' AND (';
        for ( my $i = 0 ; $i < $count ; $i++ ) {
            my $term = $data[$i];
            $query .= "(surname LIKE ? OR surname LIKE ?
                OR firstname LIKE ? OR firstname LIKE ?
                OR othernames LIKE ?
                OR initials LIKE ? ) AND ";
            push( @bind, "$term%", "% $term%", "$term%", "% $term%", "$term%", "$term%" );
        }
        $query =~ s/ AND $/ /;
        $query .= ') ';
    }

    $query .= " ORDER BY $orderby ";
    $query .= sprintf(' LIMIT %d,%d',
                      $limits->{offset}//0,
                      $limits->{limit}//C4::Context->preference('PatronsPerPage'));

    $data = $dbh->selectall_arrayref($query, {Slice => {}}, @bind);
    my ($row_count) = $dbh->selectrow_array('SELECT FOUND_ROWS()');

    # This assumes a lost barcode search will never match a patron's name.
    # Not necessarily an absolute guarantee, but it's worth the performance tradeoff.
    if (not scalar @$data) {
        $query = q/
            SELECT borrowers.*, categories.*
            FROM borrowers
              LEFT JOIN categories ON borrowers.categorycode=categories.categorycode
              LEFT JOIN statistics ON borrowers.borrowernumber = statistics.borrowernumber
            WHERE statistics.type = 'card_replaced' AND statistics.other = ?
            /;
        ($query, @bind) = _constrain_sql_by_branchcategory($query, $searchstring);
        $sth = $dbh->prepare( $query );
        $sth->execute( @bind );
        my $prevcards_data = $sth->fetchall_arrayref({});
        foreach my $row ( @$prevcards_data ) {
            $row->{'PreviousCardnumber'} = 1;
        }
        $data = [ @$prevcards_data, @$data ];
    }

    return ( $row_count, $data );
}

sub SearchMemberBySQL {
    my ( $query ) = @_;
    my @sql_params;
    ($query, @sql_params) = _constrain_sql_by_branchcategory($query);
    my $data = C4::Context->dbh->selectall_arrayref($query, {Slice=>{}}, @sql_params);
    return (scalar @$data, $data);
}

=head2 GetMemberDetails

($borrower) = &GetMemberDetails($borrowernumber, $cardnumber);

Looks up a patron and returns information about him or her. If
C<$borrowernumber> is true (nonzero), C<&GetMemberDetails> looks
up the borrower by number; otherwise, it looks up the borrower by card
number.

C<$borrower> is a reference-to-hash whose keys are the fields of the
borrowers table in the Koha database. In addition,
C<$borrower-E<gt>{flags}> is a hash giving more detailed information
about the patron. Its keys act as flags :

    if $borrower->{flags}->{LOST} {
        # Patron's card was reported lost
    }

If the state of a flag means that the patron should not be
allowed to borrow any more books, then it will have a C<noissues> key
with a true value.

See patronflags for more details.

C<$borrower-E<gt>{authflags}> is a hash giving more detailed information
about the top-level permissions flags set for the borrower.  For example,
if a user has the "editcatalogue" permission,
C<$borrower-E<gt>{authflags}-E<gt>{editcatalogue}> will exist and have
the value "1".

=cut

# not an exported function
# used to get patron categories that are of type 'S' staff
sub GetStaffCategories
{
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT categorycode FROM categories
      WHERE category_type = 'S'");
   $sth->execute();
   my @all = ();
   while (my $row = $sth->fetchrow_hashref()) {
      push @all, $row->{categorycode};
   }
   return wantarray? @all : \@all;
}

sub GetMemberDetails {
    my ( $borrowernumber, $cardnumber, $circ_session ) = @_;
    $circ_session ||= {};
    my $dbh = C4::Context->dbh;
    my $sth;
    my $sql = q{
        SELECT borrowers.*, category_type, categories.description
        FROM borrowers
          LEFT JOIN categories ON borrowers.categorycode=categories.categorycode
        WHERE
        };
    my @params;
    if ($borrowernumber) {
        $sql .= ' borrowernumber=?';
        push @params, $borrowernumber;
    }
    elsif ($cardnumber) {
        $sql .= ' cardnumber=?';
        push @params, $cardnumber;
    }
    else {
        return;
    }
    ($sql, @params) = _constrain_sql_by_branchcategory($sql, @params);
    
    my $borrower = $dbh->selectrow_hashref($sql, undef, @params);
    return if !$borrower;

    my $amount = C4::Accounts::MemberAllAccounts( 
      borrowernumber => $borrower->{borrowernumber},
      total_only     => 1
    );
    $borrower->{'amountoutstanding'} = $amount;
    # FIXME - just have patronflags return $amount
    my $flags = patronflags( $borrower, $circ_session );
    my $accessflagshash;

    $sth = $dbh->prepare('SELECT bit,flag FROM userflags');
    $sth->execute;
    while ( my ( $bit, $flag ) = $sth->fetchrow ) {
        if ( $borrower->{'flags'} && $borrower->{'flags'} & 2**$bit ) {
            $accessflagshash->{$flag} = 1;
        }
    }
    $sth->finish;
    $borrower->{'flags'}     = $flags;
    $borrower->{'authflags'} = $accessflagshash;

    # find out how long the membership lasts
    $sth = $dbh->prepare(
        'SELECT enrolmentperiod FROM categories WHERE categorycode = ?');
    $sth->execute( $borrower->{'categorycode'} );
    my $enrolment = $sth->fetchrow;
    $borrower->{'enrolmentperiod'} = $enrolment;
    return ($borrower);    #, $flags, $accessflagshash);
}

=head2 patronflags

 $flags = &patronflags($patron);

 This function is not exported.

 The following will be set where applicable:
 $flags->{CHARGES}->{amount}        Amount of debt
 $flags->{CHARGES}->{noissues}      Set if debt amount >$5.00
                                    or circ_block_threshold by patron category
 $flags->{CHARGES}->{message}       Message -- deprecated

 $flags->{CREDITS}->{amount}        Amount of credit
 $flags->{CREDITS}->{message}       Message -- deprecated

 $flags->{  GNA  }                  Patron has no valid address
 $flags->{  GNA  }->{noissues}      Set for each GNA
 $flags->{  GNA  }->{message}       "Borrower has no valid address" -- deprecated

 $flags->{ LOST  }                  Patron's card reported lost
 $flags->{ LOST  }->{noissues}      Set for each LOST
 $flags->{ LOST  }->{message}       Message -- deprecated

 $flags->{DBARRED}                  Set if patron debarred, no access
 $flags->{DBARRED}->{noissues}      Set for each DBARRED
 $flags->{DBARRED}->{message}       Message -- deprecated

 $flags->{ NOTES }
 $flags->{ NOTES }->{message}       The note itself.  NOT deprecated

 $flags->{ ODUES }                  Set if patron has overdue books.
 $flags->{ ODUES }->{message}       "Yes"  -- deprecated
 $flags->{ ODUES }->{itemlist}      ref-to-array: list of overdue books
 $flags->{ ODUES }->{itemlisttext}  Text list of overdue items -- deprecated

 $flags->{WAITING}                  Set if any of patron's reserves are available
 $flags->{WAITING}->{message}       Message -- deprecated
 $flags->{WAITING}->{itemlist}      ref-to-array: list of available items

=over 4

C<$flags-E<gt>{ODUES}-E<gt>{itemlist}> is a reference-to-array listing the
overdue items. Its elements are references-to-hash, each describing an
overdue item. The keys are selected fields from the issues, biblio,
biblioitems, and items tables of the Koha database.

C<$flags-E<gt>{ODUES}-E<gt>{itemlisttext}> is a string giving a text listing of
the overdue items, one per line.  Deprecated.

C<$flags-E<gt>{WAITING}-E<gt>{itemlist}> is a reference-to-array listing the
available items. Each element is a reference-to-hash whose keys are
fields from the reserves table of the Koha database.

=back

All the "message" fields that include language generated in this function are deprecated, 
because such strings belong properly in the display layer.

The "message" field that comes from the DB is OK.

=cut

# TODO: use {anonymous => hashes} instead of a dozen %flaginfo
# FIXME rename this function.
sub patronflags {
    my %flags;
    my ( $patroninformation, $circ_session ) = @_;
    $circ_session ||= {};

    my $amount = C4::Accounts::MemberAllAccounts( 
      borrowernumber => $patroninformation->{'borrowernumber'},
      total_only     => 1
    );
    $amount //= 0;
    my $cat = GetCategoryInfo($$patroninformation{categorycode});

    if ( $amount > 0 ) {
        my %flaginfo;
        my $cat = GetCategoryInfo($$patroninformation{categorycode});
        my $blockamount = (($$cat{circ_block_threshold}//0) > 0)? $$cat{circ_block_threshold} : 5;
        $flaginfo{'message'} = sprintf "Patron owes \$%.02f", $amount;
        $flaginfo{'amount'}  = sprintf "%.02f",$amount;
        
        if ( ($amount > $blockamount) && !$circ_session->{'charges_overridden'} ) {
            $flaginfo{'noissues'} = 1;
        }
        $flags{'CHARGES'} = \%flaginfo;
    }
    elsif ( $amount < 0 ) {
        my %flaginfo;
        $flaginfo{'message'} = sprintf "Patron has credit of \$%.02f", -$amount;
        $flaginfo{'amount'}  = sprintf "%.02f", $amount;
        $flags{'CREDITS'} = \%flaginfo;
    }
    if ($patroninformation->{'gonenoaddress'} ~~ 1) {
        my %flaginfo;
        $flaginfo{'message'}  = 'Borrower has no valid address.';
        $flaginfo{'noissues'} = 1;
        $flags{'GNA'}         = \%flaginfo;
    }
    if ($patroninformation->{'lost'} ~~ 1 ) {
        my %flaginfo;
        $flaginfo{'message'}  = 'Borrower\'s card reported lost.';
        $flaginfo{'noissues'} = 1;
        $flags{'LOST'}        = \%flaginfo;
    }
    if ($patroninformation->{'debarred'} ~~ 1) {
        my %flaginfo;
        $flaginfo{'message'}  = 'Borrower is Debarred.';
        $flaginfo{'noissues'} = 1;
        $flags{'DBARRED'}     = \%flaginfo;
    }
    if ($patroninformation->{'borrowernotes'}) {
        my %flaginfo;
        $flaginfo{'message'} = $patroninformation->{'borrowernotes'};
        $flags{'NOTES'}      = \%flaginfo;
    }
    my ( $odues, $itemsoverdue ) = checkoverdues($patroninformation->{'borrowernumber'});
    if ( $odues > 0 ) {
        my %flaginfo;
        $flaginfo{'message'}  = "Yes";
        $flaginfo{'itemlist'} = $itemsoverdue;
        foreach ( sort { $a->{'date_due'} cmp $b->{'date_due'} }
            @$itemsoverdue )
        {
            my $dd = $$_{date_due} // '';
            my $bc = $$_{barcode}  // '';
            my $ti = $$_{title}    // '';
            $flaginfo{'itemlisttext'} .= "$dd $bc $ti \n";  # newline is display layer
        }
        $flags{'ODUES'} = \%flaginfo;
    }
    my @itemswaiting = C4::Reserves::GetReservesFromBorrowernumber( $patroninformation->{'borrowernumber'},'W' );
    my $nowaiting = scalar @itemswaiting;
    if ( $nowaiting > 0 ) {
        my %flaginfo;
        $flaginfo{'message'}  = "Reserved items available";
        $flaginfo{'itemlist'} = \@itemswaiting;
        $flags{'WAITING'}     = \%flaginfo;
    }
    return ( \%flags );
}


=head2 GetMember

  $borrower = &GetMember($information, $type);

C<$type> should be one of 'borrowernumber', 'userid', or
'cardnumber' with C<$information> containing the appropriate value.
If not specified, C<$type> defaults to 'borrowernumber'.

Returns a reference-to-hash whose keys are the fields of
the C<borrowers> table in the Koha database.  If the borrower is a staff
member, an additional 'worklibraries' arrayref is included in the fields.

=cut

#'
sub GetMember {
    my ( $information, $type ) = @_;
    $type //= 'borrowernumber';

    my $select = qq{
        SELECT borrowers.*, categories.category_type, categories.description
        FROM   borrowers 
          LEFT JOIN categories ON borrowers.categorycode=categories.categorycode 
        WHERE  $type = ?
        };
    my @params = ($information);
    ($select, @params) = _constrain_sql_by_branchcategory($select, @params);
    my $borrower = C4::Context->dbh->selectrow_hashref($select, undef, @params);
    return undef if !$borrower;

    if ($borrower->{category_type} ~~ 'S') { # staff
        $borrower->{worklibraries} = GetWorkLibraries($borrower->{borrowernumber});
    }

    return $borrower;
}

=head2 GetMemberIssuesAndFines

  ($overdue_count, $issue_count, $total_fines) = &GetMemberIssuesAndFines($borrowernumber);

Returns aggregate data about items borrowed by the patron with the
given borrowernumber.

C<&GetMemberIssuesAndFines> returns a three-element array.  C<$overdue_count> is the
number of overdue items the patron currently has borrowed. C<$issue_count> is the
number of books the patron currently has borrowed.  C<$total_fines> is
the total fine currently due by the borrower.

=cut

#'
sub GetMemberIssuesAndFines {
    my ( $borrowernumber ) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = "SELECT COUNT(*) FROM issues WHERE borrowernumber = ?";

    $debug and warn $query."\n";
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    my $issue_count = $sth->fetchrow_arrayref->[0];
    $sth->finish;

    # subtract Claims Returned items
    $sth = $dbh->prepare("SELECT COUNT(*) FROM lost_items 
      WHERE borrowernumber  = ?
        AND claims_returned = 1");
    $sth->execute($borrowernumber);
    $issue_count -= ($sth->fetchrow_array)[0];

    $sth = $dbh->prepare(
        "SELECT COUNT(*) FROM issues 
         WHERE borrowernumber = ? 
         AND date_due < now()"
    );
    $sth->execute($borrowernumber);
    my $overdue_count = $sth->fetchrow_arrayref->[0];
    $sth->finish;

    $sth = $dbh->prepare("SELECT SUM(amountoutstanding) FROM accountlines WHERE borrowernumber = ?");
    $sth->execute($borrowernumber);
    my $total_fines = $sth->fetchrow_arrayref->[0];
    $sth->finish;

    return ($overdue_count, $issue_count, $total_fines);
}

sub columns(;$) {
    return @{C4::Context->dbh->selectcol_arrayref("SHOW columns from borrowers")};
}

=head2

=head2 ModMember

=over 4

my $success = ModMember(borrowernumber => $borrowernumber, [ field => value ]... );

Modify borrower's data.  All date fields should ALREADY be in ISO format.

return :
true on success, or false on failure

=back

=cut

sub ModMember {
    my (%data) = @_;
    my $dbh = C4::Context->dbh;
    
    my $member = GetMemberDetails( $data{'borrowernumber'} );
    return if not defined $member;

    if ( exists $data{'cardnumber'} and $member->{'cardnumber'} ne $data{'cardnumber'} ) {
        my $branch = (C4::Context->userenv) ? C4::Context->userenv->{branch} : undef;
        C4::Stats::UpdateStats( $branch, 'card_replaced', '', $member->{'cardnumber'}, '', '', $data{'borrowernumber'} );
    }

    my ($oldval,$newval);
    my $staffnumber = C4::Context->userenv->{'number'};
    delete $data{'staffnumber'};
    my $worklibraries = $data{worklibrary};
    delete $data{worklibrary};
    my $sth;
    my $query = "
      INSERT INTO borrower_edits
        (borrowernumber,staffnumber,field,before_value,after_value)
      VALUES (?,?,?,?,?)";
    foreach (keys %data) {
      if ($member->{$_} ne $data{$_}) {
        $oldval = $member->{$_};
        $newval = $data{$_};
        next if ($_ eq 'password' && ($newval eq '****'));
        $sth = $dbh->prepare($query);
        $sth->execute($data{'borrowernumber'},$staffnumber,$_,$oldval,$newval);
      }
    }
    my $iso_re = C4::Dates->new()->regexp('iso');
    foreach (qw(dateofbirth dateexpiry dateenrolled)) {
        if (my $tempdate = $data{$_}) {                                 # assignment, not comparison
            ($tempdate =~ /$iso_re/) and next;                          # Congatulations, you sent a valid ISO date.
            warn "ModMember given $_ not in ISO format ($tempdate)";
            my $tempdate2 = format_date_in_iso($tempdate);
            if (!$tempdate2 or $tempdate2 eq '0000-00-00') {
                warn "ModMember cannot convert '$tempdate' (from syspref to ISO)";
                next;
            }
            $data{$_} = $tempdate2;
        }
    }
    if (!$data{'dateofbirth'}){
        delete $data{'dateofbirth'};
    }
    my @columns = &columns;
    my %hashborrowerfields = (map {$_=>1} @columns);
    $query = "UPDATE borrowers SET \n";
    my @parameters;  
    
    # test to know if you must update or not the borrower password
    if (exists $data{password}) {
        if ($data{password} eq '****' or $data{password} eq '') {
            delete $data{password};
        } else {
            $data{password} = md5_base64($data{password});
        }
    }
    # modify cardnumber if necessary.
    if(C4::Context->preference('patronbarcodelength') && exists($data{'cardnumber'})){
        $data{'cardnumber'} = _prefix_cardnum(cardnumber=>$data{'cardnumber'}); 
        # TODO : generate error if cardnumber does not match barcode schema, 
        #        or length not sufficient to prefix without corrupting input string.
    }
    my @badkeys;
    foreach (keys %data) {  
        next if ($_ eq 'borrowernumber' or $_ eq 'flags');
        next if $_ eq 'select_city';
        if ($hashborrowerfields{$_}){
            $query .= " $_=?, "; 
            push @parameters,$data{$_};
        } else {
            push @badkeys, $_;
            delete $data{$_};
        }
    }
    (@badkeys) and warn scalar(@badkeys) . " Illegal key(s) passed to ModMember: " . join(',',@badkeys);
    $query =~ s/, $//;
    $query .= " WHERE borrowernumber=?";
    push @parameters, $data{'borrowernumber'};
    $debug and print STDERR "$query (executed w/ arg: $data{'borrowernumber'})";
    $sth = $dbh->prepare($query);
    my $execute_success = $sth->execute(@parameters);
    $sth->finish;

# ok if its an adult (type) it may have borrowers that depend on it as a guarantor
# so when we update information for an adult we should check for guarantees and update the relevant part
# of their records, ie addresses and phone numbers
    my $borrowercategory= GetBorrowercategory( $data{'category_type'} );
    if ( exists  $borrowercategory->{'category_type'} && $borrowercategory->{'category_type'} eq ('A' || 'S') ) {
        # is adult check guarantees;
        UpdateGuarantees(%data);
    }
    logaction("MEMBERS", "MODIFY", $data{'borrowernumber'}, "$query (executed w/ arg: $data{'borrowernumber'})") 
        if C4::Context->preference("BorrowersLog");

   # a staff member's work libraries
   if (defined $worklibraries) {
      $sth = $dbh->prepare("DELETE FROM borrower_worklibrary
      WHERE borrowernumber = ?");
      $sth->execute($data{borrowernumber});
      foreach(@$worklibraries) {
          $sth = $dbh->prepare("INSERT INTO borrower_worklibrary
          (borrowernumber,branchcode) VALUES (?,?)");
          $sth->execute($data{borrowernumber},$_);
      }
   }
   return $execute_success;
}

sub GetWorkLibraries {
   my $borrowernumber = shift;
   my $branches
       = C4::Context->dbh->selectcol_arrayref(q{
            SELECT branchcode as worklibrary
            FROM   borrower_worklibrary
            WHERE  borrowernumber = ?
            }, undef, $borrowernumber);
   return wantarray ? @{$branches} : $branches;
}


=head2

=head2 AddMember

  $borrowernumber = &AddMember(%borrower);

insert new borrower into table
Returns the borrowernumber

=cut

#'
sub AddMember {
    my (%data) = @_;
    my $dbh = C4::Context->dbh;
    $data{'userid'} = '' unless $data{'password'};
    $data{'password'} = md5_base64( $data{'password'} ) if $data{'password'};
    $data{'cardnumber'} = _prefix_cardnum(cardnumber=>$data{'cardnumber'}) if(C4::Context->preference('patronbarcodelength'));

    # WE SHOULD NEVER PASS THIS SUBROUTINE ANYTHING OTHER THAN ISO DATES
    # IF YOU UNCOMMENT THESE LINES YOU BETTER HAVE A DARN COMPELLING REASON
#    $data{'dateofbirth'}  = format_date_in_iso( $data{'dateofbirth'} );
#    $data{'dateenrolled'} = format_date_in_iso( $data{'dateenrolled'});
#    $data{'dateexpiry'}   = format_date_in_iso( $data{'dateexpiry'}  );
    # This query should be rewritten to use "?" at execute.
    # Done -hQ
    if (!$data{'dateofbirth'}){
        undef ($data{'dateofbirth'});
    }
   
   $data{exclude_from_collection} ||= 0;
   my @f = qw(cardnumber surname firstname title othernames initials
      streetnumber streettype address address2 zipcode country city
      phone email mobile phonepro opacnote guarantorid dateofbirth
      branchcode categorycode dateenrolled contactname
      borrowernotes dateexpiry contactnote
      B_address B_address2 B_zipcode B_country B_city B_email
      B_streetnumber B_streettype
      password userid sort1 sort2
      contacttitle emailpro contactfirstname
      sex fax relationship gonenoaddress
      exclude_from_collection lost debarred
      ethnicity ethnotes
      altcontactsurname altcontactfirstname
      altcontactaddress1 altcontactaddress2 altcontactaddress3
      altcontactzipcode altcontactcountry altcontactphone
      disable_reading_history
   );
   my @params = ();
   my $query = sprintf("insert into borrowers(%s) values(%s)",
      join(',', @f),
      join(',',map{'?'}@f),
   );
   foreach(@f) { push @params, $data{$_} };


    my $sth = $dbh->prepare($query);
    #   print "Executing SQL: $query\n";
    $sth->execute(@params) or die sprintf "Failed to insert member data: %s\n", $dbh->errstr;
    $sth->finish;
    $data{'borrowernumber'} = $dbh->{'mysql_insertid'};     # unneeded w/ autoincrement ?  
    # mysql_insertid is probably bad.  not necessarily accurate and mysql-specific at best.
    
    logaction("MEMBERS", "CREATE", $data{'borrowernumber'}, "") if C4::Context->preference("BorrowersLog");
    
    # check for enrollment fee & add it if needed
    $sth = $dbh->prepare("SELECT enrolmentfee FROM categories WHERE categorycode=?");
    $sth->execute($data{'categorycode'});
    my ($enrolmentfee) = $sth->fetchrow;
    if ($enrolmentfee && $enrolmentfee > 0) {
        # insert fee in patron debts
        C4::Accounts::manualinvoice(
         borrowernumber => $data{'borrowernumber'},
         accounttype    => 'A', 
         amount         => $enrolmentfee
        );
    }

    # work libraries
    if (@{$data{worklibrary} // []}) {
        $sth = $dbh->prepare("DELETE FROM borrower_worklibrary
        WHERE borrowernumber = ?") || die $dbh->errstr();
        $sth->execute($data{borrowernumber});
        foreach(@{$data{worklibrary}}) {
            $sth = $dbh->prepare("INSERT INTO borrower_worklibrary
            (borrowernumber,branchcode) VALUES(?,?)") || die $dbh->errstr();
            $sth->execute($data{borrowernumber},$_) || die $dbh->errstr();
        }
    }
    return $data{'borrowernumber'};
}

sub Check_Userid {
    my ($uid,$member) = @_;
    my $dbh = C4::Context->dbh;
    # Make sure the userid chosen is unique and not theirs if non-empty. If it is not,
    # Then we need to tell the user and have them create a new one.
    my $sth =
      $dbh->prepare(
        "SELECT * FROM borrowers WHERE userid=? AND borrowernumber != ?");
    $sth->execute( $uid, $member );
    if ( ( $uid ne '' ) && ( my $row = $sth->fetchrow_hashref ) ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub Generate_Userid {
  my ($borrowernumber, $firstname, $surname) = @_;
  my $newuid;
  my $offset = 0;
  do {
    $firstname =~ s/[[:digit:][:space:][:blank:][:punct:][:cntrl:]]//g;
    $surname =~ s/[[:digit:][:space:][:blank:][:punct:][:cntrl:]]//g;
    $newuid = lc("$firstname.$surname");
    $newuid .= $offset unless $offset == 0;
    $offset++;

   } while (!Check_Userid($newuid,$borrowernumber));

   return $newuid;
}

sub changepassword {
    my ( $uid, $member, $digest ) = @_;
    my $dbh = C4::Context->dbh;

#Make sure the userid chosen is unique and not theirs if non-empty. If it is not,
#Then we need to tell the user and have them create a new one.
    my $resultcode;
    my $sth =
      $dbh->prepare(
        "SELECT * FROM borrowers WHERE userid=? AND borrowernumber != ?");
    $sth->execute( $uid, $member );
    if ( ( $uid ne '' ) && ( my $row = $sth->fetchrow_hashref ) ) {
        $resultcode=0;
    }
    else {
        #Everything is good so we can update the information.
        $sth =
          $dbh->prepare(
            "update borrowers set userid=?, password=? where borrowernumber=?");
        $sth->execute( $uid, $digest, $member );
        $resultcode=1;
    }
    
    logaction("MEMBERS", "CHANGE PASS", $member, "") if C4::Context->preference("BorrowersLog");
    return $resultcode;    
}



=head2 fixup_cardnumber

get next available cardnumber.
Warning: The caller is responsible for locking the members table in write
mode, to avoid database corruption.

=cut

use vars qw( @weightings );
my @weightings = ( 8, 4, 6, 3, 5, 2, 1 );

sub fixup_cardnumber {
    my ($cardnumber, $branch) = @_;
    my $autonumber_members = C4::Context->boolean_preference('autoMemberNum') || 0;

    # Find out whether member numbers should be generated
    # automatically. Should be either "1" or something else.
    # Defaults to "0", which is interpreted as "no".

    ($autonumber_members) or return $cardnumber;
    my $checkdigit = C4::Context->preference('checkdigit');
    my $dbh = C4::Context->dbh;
    if ( $checkdigit and $checkdigit eq 'katipo' ) {

        # if checkdigit is selected, calculate katipo-style cardnumber.
        # purpose: generate checksum'd member numbers.
        # We'll assume we just got the max value of digits 2-8 of member #'s
        # from the database and our job is to increment that by one,
        # determine the 1st and 9th digits and return the full string.
        my $sth = $dbh->prepare(
            "select max(substring(borrowers.cardnumber,2,7)) as new_num from borrowers"
        );
        $sth->execute;
        my $data = $sth->fetchrow_hashref;
        $cardnumber = $data->{new_num};
        if ( !$cardnumber ) {    # If DB has no values,
            $cardnumber = 1000000;    # start at 1000000
        } else {
            $cardnumber += 1;
        }

        my $sum = 0;
        for ( my $i = 0 ; $i < 8 ; $i += 1 ) {
            # read weightings, left to right, 1 char at a time
            my $temp1 = $weightings[$i];

            # sequence left to right, 1 char at a time
            my $temp2 = substr( $cardnumber, $i, 1 );

            # mult each char 1-7 by its corresponding weighting
            $sum += $temp1 * $temp2;
        }

        my $rem = ( $sum % 11 );
        $rem = 'X' if $rem == 10;

        return "V$cardnumber$rem";
     } else {

     # increment operator without cast(int) should be safe, and should properly increment
     # whether the string is numeric or not.
     # FIXME : This needs to be pulled out into an ajax function, since the interface allows on-the-fly changing of patron home library.
     #
         my $query;
         my @bind;
         my $cardlength = C4::Context->preference('patronbarcodelength');
         my $firstnumber = 0;
         if($branch->{'patronbarcodeprefix'} && $cardlength) {
            $query =  "select max(cardnumber) from borrowers ";
             my $minrange = 10**($cardlength-length($branch->{'patronbarcodeprefix'}) );
             $query .= " WHERE cardnumber BETWEEN ? AND ?";
             $query .= " AND length(cardnumber) = ?";
             $firstnumber = $branch->{'patronbarcodeprefix'} .substr(sprintf("%s",$minrange), 1) ;
             @bind = ($firstnumber , $branch->{'patronbarcodeprefix'} . sprintf( "%s",$minrange - 1),$cardlength ) ;
         } else {
            # not using prefix; assume we just want to increment the largest integer barcode.
            # note mysql throws lots of warnings on this for alphanumeric cardnumbers.
            $query =  "select max(cast(cardnumber as signed)) from borrowers ";
         }
         my $sth= $dbh->prepare($query);
         $sth->execute(@bind);
         my ($result) = $sth->fetchrow;
         $sth->finish;
         if($result) {
             $result =~ s/^$branch->{'patronbarcodeprefix'}//;
             my $cnt = 0;
             while ( $result =~ /([a-zA-Z]*[0-9]*)\z/ ) {   # use perl's magical stringcrement behavior (++).
                 my $incrementable = $1;
                 $incrementable++;
                 if ( length($incrementable) > length($1) ) { # carry a digit to next incrementable fragment
                     $cardnumber = substr($incrementable,1) . $cardnumber;
                     $result = $`;
                 } else {
                     $cardnumber = $branch->{'patronbarcodeprefix'} . $` . $incrementable . $cardnumber ;
                     last;
                 }
                 last if(++$cnt>10);
             }
         } else {
             $cardnumber =  ++$firstnumber ;
         }
     }
    return $cardnumber;     # just here as a fallback/reminder 
}

=head2 GetGuarantees

  ($num_children, $children_arrayref) = &GetGuarantees($parent_borrno);
  $child0_cardno = $children_arrayref->[0]{"cardnumber"};
  $child0_borrno = $children_arrayref->[0]{"borrowernumber"};

C<&GetGuarantees> takes a borrower number (e.g., that of a patron
with children) and looks up the borrowers who are guaranteed by that
borrower (i.e., the patron's children).

C<&GetGuarantees> returns two values: an integer giving the number of
borrowers guaranteed by C<$parent_borrno>, and a reference to an array
of references to hash, which gives the actual results.

=cut

#'
sub GetGuarantees {
    my ($borrowernumber) = @_;
    my $dbh              = C4::Context->dbh;
    my $sth              =
      $dbh->prepare(
"select cardnumber,borrowernumber, firstname, surname from borrowers where guarantorid=?"
      );
    $sth->execute($borrowernumber);

    my @dat;
    my $data = $sth->fetchall_arrayref({}); 
    $sth->finish;
    return ( scalar(@$data), $data );
}

=head2 UpdateGuarantees

  &UpdateGuarantees($parent_borrno);
  

C<&UpdateGuarantees> borrower data for an adult and updates all the guarantees
with the modified information

=cut

#'
sub UpdateGuarantees {
    my (%data) = @_;
    my $dbh = C4::Context->dbh;
    my ( $count, $guarantees ) = GetGuarantees( $data{'borrowernumber'} );
    for ( my $i = 0 ; $i < $count ; $i++ ) {

        # FIXME
        # It looks like the $i is only being returned to handle walking through
        # the array, which is probably better done as a foreach loop.
        #
        my $guaquery = qq|UPDATE borrowers 
              SET address='$data{'address'}',fax='$data{'fax'}',
                  B_city='$data{'B_city'}',mobile='$data{'mobile'}',city='$data{'city'}',phone='$data{'phone'}'
              WHERE borrowernumber='$guarantees->[$i]->{'borrowernumber'}'
        |;
        my $sth3 = $dbh->prepare($guaquery);
        $sth3->execute;
        $sth3->finish;
    }
}
=head2 GetPendingIssues

  my $issues = &GetPendingIssues($borrowernumber);

Looks up what the patron with the given borrowernumber has borrowed.
*** NOTE *** skips Claims Returned items

C<&GetPendingIssues> returns a
reference-to-array where each element is a reference-to-hash; the
keys are the fields from the C<issues>, C<biblio>, and C<items> tables.
The keys include C<biblioitems> fields except marc and marcxml.

=cut

#'
sub GetPendingIssues {
    my ($borrowernumber) = @_;
    # must avoid biblioitems.* to prevent large marc and marcxml fields from killing performance
    # FIXME: namespace collision: each table has "timestamp" fields.  Which one is "timestamp" ?
    # FIXME: circ/ciculation.pl tries to sort by timestamp!
    # FIXME: C4::Print::printslip tries to sort by timestamp!
    # FIXME: namespace collision: other collisions possible.
    # FIXME: most of this data isn't really being used by callers.
    my $sth = C4::Context->dbh->prepare(
   "SELECT issues.*,
            items.*,
           biblio.*,
           biblioitems.volume,
           biblioitems.number,
           biblioitems.itemtype,
           biblioitems.isbn,
           biblioitems.issn,
           biblioitems.publicationyear,
           biblioitems.publishercode,
           biblioitems.volumedate,
           biblioitems.volumedesc,
           biblioitems.lccn,
           biblioitems.url,
           issues.timestamp AS timestamp,
           issues.renewals  AS renewals,
            items.renewals  AS totalrenewals
    FROM   issues
    LEFT JOIN items       ON items.itemnumber       =      issues.itemnumber
    LEFT JOIN biblio      ON items.biblionumber     =      biblio.biblionumber
    LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
    WHERE
      borrowernumber=?
    ORDER BY issues.issuedate"
    );
    $sth->execute($borrowernumber);
    my $data = $sth->fetchall_arrayref({});
    my $today = C4::Dates->new->output('iso');
    my @new = ();
    use C4::LostItems;
    foreach (@$data) {
        $_->{date_due} or next;
        ($_->{date_due} lt $today) and $_->{overdue} = 1;
        my $claims_returned = C4::LostItems::isClaimsReturned(
         $$_{itemnumber},
         $borrowernumber
        );
        if (defined $claims_returned) {
            if ($claims_returned) {
               next;
            }
        }
        push @new, $_;
    }
    return \@new;
}

=head2 GetAllIssues

  ($count, $issues) = &GetAllIssues($borrowernumber, $sortkey, $limit);

Looks up what the patron with the given borrowernumber has borrowed,
and sorts the results.

C<$sortkey> is the name of a field on which to sort the results. This
should be the name of a field in the C<issues>, C<biblio>,
C<biblioitems>, or C<items> table in the Koha database.

C<$limit> is the maximum number of results to return.

C<&GetAllIssues> returns a two-element array. C<$issues> is a
reference-to-array, where each element is a reference-to-hash; the
keys are the fields from the C<issues>, C<biblio>, C<biblioitems>, and
C<items> tables of the Koha database. C<$count> is the number of
elements in C<$issues>

=cut

#'
sub GetAllIssues {
    my ( $borrowernumber, $order, $limit ) = @_;

    #FIXME: sanity-check order and limit
    my $dbh   = C4::Context->dbh;
    my $count = 0;
    my $query =
  "SELECT *,issues.renewals AS renewals,items.renewals AS totalrenewals,items.timestamp AS itemstimestamp 
  FROM issues 
  LEFT JOIN items on items.itemnumber=issues.itemnumber
  LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber
  LEFT JOIN biblioitems ON items.biblioitemnumber=biblioitems.biblioitemnumber
  WHERE borrowernumber=? 
  UNION ALL
  SELECT *,old_issues.renewals AS renewals,items.renewals AS totalrenewals,items.timestamp AS itemstimestamp 
  FROM old_issues 
  LEFT JOIN items on items.itemnumber=old_issues.itemnumber
  LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber
  LEFT JOIN biblioitems ON items.biblioitemnumber=biblioitems.biblioitemnumber
  WHERE borrowernumber=? 
  order by $order";
    if ( $limit != 0 ) {
        $query .= " limit $limit";
    }

    #print $query;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber, $borrowernumber);
    my @result;
    my $i = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        ( $data->{'charge'} ) = C4::Circulation::GetIssuingCharges( $data->{'itemnumber'}, $borrowernumber );
        $result[$i] = $data;
        $i++;
        $count++;
    }

    return ( $i, \@result );
}

sub GetEarliestDueDate {
    my ( $borrowernumber ) = @_;
    my $dbh = C4::Context->dbh;

    return $dbh->selectrow_array( "
        SELECT
          date_due
          FROM issues
          WHERE borrowernumber = ?
          ORDER BY date_due ASC
          LIMIT 1
    ", {}, $borrowernumber );
}


=head2 GetBorNotifyAcctRecord

  ($count, $acctlines, $total) = &GetBorNotifyAcctRecord($params,$notifyid);

Looks up accounting data for the patron with the given borrowernumber per file number.

(FIXME - I'm not at all sure what this is about.)

C<&GetBorNotifyAcctRecord> returns a three-element array. C<$acctlines> is a
reference-to-array, where each element is a reference-to-hash; the
keys are the fields of the C<accountlines> table in the Koha database.
C<$count> is the number of elements in C<$acctlines>. C<$total> is the
total amount outstanding for all of the account lines.

=cut

sub GetBorNotifyAcctRecord {
    my ( $borrowernumber, $notifyid ) = @_;
    my $dbh = C4::Context->dbh;
    my @acctlines;
    my $numlines = 0;
    my $sth = $dbh->prepare(
            "SELECT * 
                FROM accountlines 
                WHERE borrowernumber=? 
                    AND notify_id=? 
                    AND amountoutstanding != '0' 
                ORDER BY notify_id,accounttype
                ");
#                    AND (accounttype='FU' OR accounttype='N' OR accounttype='M'OR accounttype='A'OR accounttype='F'OR accounttype='L' OR accounttype='IP' OR accounttype='CH' OR accounttype='RE' OR accounttype='RL')

    $sth->execute( $borrowernumber, $notifyid );
    my $total = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        $acctlines[$numlines] = $data;
        $numlines++;
        $total += int(100 * $data->{'amountoutstanding'});
    }
    $total /= 100;
    $sth->finish;
    return ( $total, \@acctlines, $numlines );
}

sub GetMemberLostItems
{
   my %g   = @_;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare('
      SELECT * FROM lost_items
       WHERE borrowernumber = ?
    ORDER BY date_lost DESC');
   $sth->execute($g{borrowernumber});
   my @all = ();
   while(my $row = $sth->fetchrow_hashref()) { 
      next if ($g{only_claimsreturned} && !$$row{claims_returned});
      if ($g{formatdate}) {
         $$row{date_lost} = C4::Dates::format_date($$row{date_lost});
      }
      push @all, $row;
   }
   return \@all;
}

sub GetLostStats {
    my ( $borrowernumber, $hide_old ) = @_;
    my $dbh = C4::Context->dbh;
    my $category = GetAuthValCode( 'items.itemlost', '' );
    my %summary;

    my $lost_items = $dbh->selectall_arrayref( "
        SELECT
          authorised_values.lib as description, value, statistics.itemnumber,
          items.itemnumber as item_exists, items.itemlost, items.paidfor
          FROM statistics
            LEFT JOIN items ON (statistics.itemnumber = items.itemnumber)
            LEFT JOIN authorised_values ON (authorised_value = itemlost AND authorised_values.category = ?)
          WHERE statistics.type = 'itemlost' AND statistics.borrowernumber = ?
          GROUP BY statistics.itemnumber
          ORDER BY authorised_values.lib
    ", { Slice => {} }, $category, $borrowernumber );

    foreach my $item ( @$lost_items ) {
        next if ( $hide_old && ( !$item->{'item_exists'} || !$item->{'itemlost'} || $item->{'paidfor'} ) );
        my $type_summary = ( $summary{$item->{'itemlost'}} ||= {
           description => $item->{'description'},
           items => [],
           total_amount => 0,
        } );

        my $iteminfo = GetItem( $item->{'itemnumber'} );

        push @{ $type_summary->{'items'} }, {
            biblionumber => $iteminfo->{'biblionumber'},
            itemnumber => $iteminfo->{'itemnumber'},
            barcode => $iteminfo->{'barcode'},
        };

        $type_summary->{'total_amount'} += $item->{'value'};
    }

    return [ map { $_->{'total_amount'} = sprintf( '%0.2f', $_->{'total_amount'} ); $_ } values %summary ];
}

sub GetNotifiedMembers {
    my ( $wait, $max_wait, $branchcode, @ignored_categories ) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "
        SELECT
          borrowers.borrowernumber, cardnumber,
          surname, firstname, address, address2, city, zipcode, dateofbirth,
          phone, phonepro, contactfirstname, contactname, categorycode,
          last_reported_date, last_reported_amount, exclude_from_collection
        FROM borrowers
        WHERE
          amount_notify_date IS NOT NULL
          AND CURRENT_DATE BETWEEN DATE_ADD(amount_notify_date, INTERVAL ? DAY)
          AND DATE_ADD(amount_notify_date, INTERVAL ? DAY)
    ";

    $query .= " AND categorycode NOT IN (" . join( ", ", map( { "?" } @ignored_categories ) ) . ")" if ( @ignored_categories );

    if ( $branchcode ) {
        $query .= " AND borrowers.branchcode = ?";
        $query .= " GROUP BY borrowers.borrowernumber";
        push @ignored_categories, $branchcode; # Just to get it in the right place
    }

    return $dbh->selectall_arrayref( $query, { Slice => {} }, $wait, $max_wait, @ignored_categories );
}

sub MarkMemberReported {
    my ( $borrowernumber, $amount ) = @_;

    my $dbh = C4::Context->dbh;
    my $sth;
    if ($amount == 0) {
      $sth = $dbh->prepare( "
          UPDATE borrowers
            SET last_reported_date = CURRENT_DATE,
              last_reported_amount = ?,
              amount_notify_date   = NULL
            WHERE borrowernumber = ?
      " );
    }
    else {
      $sth = $dbh->prepare( "
          UPDATE borrowers
            SET last_reported_date = CURRENT_DATE,
              last_reported_amount = ?
            WHERE borrowernumber = ?
      " );
    }
    $sth->execute( $amount, $borrowernumber );
}

=head2 checkuniquemember (OUEST-PROVENCE)

  ($result,$categorycode)  = &checkuniquemember($collectivity,$surname,$firstname,$dateofbirth);

Checks that a member exists or not in the database.

C<&result> is nonzero (=exist) or 0 (=does not exist)
C<&categorycode> is from categorycode table
C<&collectivity> is 1 (= we add a collectivity) or 0 (= we add a physical member)
C<&surname> is the surname
C<&firstname> is the firstname (only if collectivity=0)
C<&dateofbirth> is the date of birth in ISO format (only if collectivity=0)

=cut

# FIXME: This function is not legitimate.  Multiple patrons might have the same first/last name and birthdate.
# This is especially true since first name is not even a required field.

sub checkuniquemember {
    my ( $collectivity, $surname, $firstname, $dateofbirth ) = @_;
    my $dbh = C4::Context->dbh;
    my $request = ($collectivity) ?
        "SELECT borrowernumber,categorycode FROM borrowers WHERE surname=? " :
            ($dateofbirth) ?
            "SELECT borrowernumber,categorycode FROM borrowers WHERE surname=? and firstname=?  and dateofbirth=?" :
            "SELECT borrowernumber,categorycode FROM borrowers WHERE surname=? and firstname=?";
    my $sth = $dbh->prepare($request);
    if ($collectivity) {
        $sth->execute( uc($surname) );
    } elsif($dateofbirth){
        $sth->execute( uc($surname), ucfirst($firstname), $dateofbirth );
    }else{
        $sth->execute( uc($surname), ucfirst($firstname));
    }
    my @data = $sth->fetchrow;
    $sth->finish;
    ( $data[0] ) and return $data[0], $data[1];
    return 0;
}

sub checkcardnumber {
    my ($cardnumber,$borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM borrowers WHERE cardnumber=?";
    $query .= " AND borrowernumber <> ?" if ($borrowernumber);
  my $sth = $dbh->prepare($query);
  if ($borrowernumber) {
   $sth->execute($cardnumber,$borrowernumber);
  } else { 
     $sth->execute($cardnumber);
  } 
    if (my $data= $sth->fetchrow_hashref()){
        return 1;
    }
    else {
        return 0;
    }
    $sth->finish();
}  


=head2 getzipnamecity (OUEST-PROVENCE)

take all info from table city for the fields city and  zip
check for the name and the zip code of the city selected

=cut

sub getzipnamecity {
    my ($cityid) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      =
      $dbh->prepare(
        "select city_name,city_zipcode from cities where cityid=? ");
    $sth->execute($cityid);
    my @data = $sth->fetchrow;
    return $data[0], $data[1];
}


=head2 getdcity (OUEST-PROVENCE)

recover cityid  with city_name condition

=cut

sub getidcity {
    my ($city_name) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select cityid from cities where city_name=? ");
    $sth->execute($city_name);
    my $data = $sth->fetchrow;
    return $data;
}

=head2 GetFirstValidEmailAddress

  $email = GetFirstValidEmailAddress($borrowernumber);

Return the first valid email address for a borrower, given the borrowernumber.  For now, the order 
is defined as email, emailpro, B_email.  Returns the empty string if the borrower has no email 
addresses.

=cut

sub GetFirstValidEmailAddress {
    my $borrowernumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( "SELECT email, emailpro, B_email FROM borrowers where borrowernumber = ? ");
    $sth->execute( $borrowernumber );
    my $data = $sth->fetchrow_hashref;

    if ($data->{'email'}) {
       return $data->{'email'};
    } elsif ($data->{'emailpro'}) {
       return $data->{'emailpro'};
    } elsif ($data->{'B_email'}) {
       return $data->{'B_email'};
    } else {
       return '';
    }
}

=head2 GetExpiryDate 

  $expirydate = GetExpiryDate($categorycode, $dateenrolled);

Calculate expiry date given a categorycode and starting date.  Date argument must be in ISO format.
Return date is also in ISO format.

=cut

sub GetExpiryDate {
    my ( $categorycode, $dateenrolled ) = @_;
    my $enrolmentperiod = 12;   # reasonable default
    if ($categorycode) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("select enrolmentperiod from categories where categorycode=?");
        $sth->execute($categorycode);
        $enrolmentperiod = $sth->fetchrow;
    }
    # die "GetExpiryDate: for enrollmentperiod $enrolmentperiod (category '$categorycode') starting $dateenrolled.\n";
    my @date = split /-/,$dateenrolled;
    return sprintf("%04d-%02d-%02d", Add_Delta_YM(@date,0,$enrolmentperiod));
}

=head2 GetMemberRevisions

=over 4

$revisions = &GetMemberRevisions($borrowernumber);

Looks up addition/modification occurences of a patron's
account by library staff via the action_logs table.
Uses patron's borrowernumber for database selection.

&GetMemberRevisions returns a reference-to array where each element
is a reference-to-hash whose keys are the fields of the action_logs
table.

=cut

#'
sub GetMemberRevisions {

    my ($borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    my $select = "
    SELECT *
      FROM action_logs
      WHERE object=?
    ";
    $sth = $dbh->prepare($select);
    $sth->execute($borrowernumber);
    my $data = $sth->fetchall_arrayref({});
    ($data) and return ($data);

    return undef;
}

=head2 checkuserpassword (OUEST-PROVENCE)

check for the password and login are not used
return the number of record 
0=> NOT USED 1=> USED

=cut

sub checkuserpassword {
    my ( $borrowernumber, $userid, $password ) = @_;
    $password = md5_base64($password);
    my $dbh = C4::Context->dbh;
    my $sth =
      $dbh->prepare(
"Select count(*) from borrowers where borrowernumber !=? and userid =? and password=? "
      );
    $sth->execute( $borrowernumber, $userid, $password );
    my $number_rows = $sth->fetchrow;
    return $number_rows;

}

=head2 GetborCatFromCatType

  ($codes_arrayref, $labels_hashref) = &GetborCatFromCatType();

Looks up the different types of borrowers in the database. Returns two
elements: a reference-to-array, which lists the borrower category
codes, and a reference-to-hash, which maps the borrower category codes
to category descriptions.

=cut

#'
sub GetborCatFromCatType {
    my ( $category_type, $action ) = @_;
	# FIXME - This API  seems both limited and dangerous. 
    my $dbh     = C4::Context->dbh;
    my $request = qq|   SELECT categorycode,description 
            FROM categories 
            $action
            ORDER BY categorycode|;
    my $sth = $dbh->prepare($request);
	if ($action) {
        $sth->execute($category_type);
    }
    else {
        $sth->execute();
    }

    my %labels;
    my @codes;

    while ( my $data = $sth->fetchrow_hashref ) {
        push @codes, $data->{'categorycode'};
        $labels{ $data->{'categorycode'} } = $data->{'description'};
    }
    $sth->finish;
    return ( \@codes, \%labels );
}

=head2 GetBorrowercategory

  $hashref = &GetBorrowercategory($categorycode);

Given the borrower's category code, the function returns the corresponding
data hashref for a comprehensive information display.
  
  $arrayref_hashref = &GetBorrowercategory;
If no category code provided, the function returns all the categories.

=cut

## Given a borrower's category, get data from the
## categories table.
sub GetCategoryInfo
{
   my $categorycode = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("
      SELECT * FROM categories
       WHERE categorycode = ?
   ");
   $sth->execute($categorycode);
   return $sth->fetchrow_hashref() // {};
}

sub GetBorrowerFromUser
{
   my $userid = shift;
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT borrowernumber FROM borrowers
   WHERE userid = ?") || die $dbh->errstr();
   $sth->execute($userid) || die $dbh->errstr();
   return ($sth->fetchrow_array)[0];
}

sub GetBorrowercategory {
    my ($catcode) = @_;
    my $dbh       = C4::Context->dbh;
    if ($catcode){
        my $sth       =
        $dbh->prepare(
    "SELECT description,dateofbirthrequired,upperagelimit,category_type 
    FROM categories 
    WHERE categorycode = ?"
        );
        $sth->execute($catcode);
        my $data =
        $sth->fetchrow_hashref;
        $sth->finish();
        return $data;
    } 
    return;  
}    # sub getborrowercategory

=head2 GetBorrowercategoryList
 
  $arrayref_hashref = &GetBorrowercategoryList;
If no category code provided, the function returns all the categories.

=cut

sub GetBorrowercategoryList {
    my $dbh       = C4::Context->dbh;
    my $sth       =
    $dbh->prepare(
    "SELECT * 
    FROM categories 
    ORDER BY description"
        );
    $sth->execute;
    my $data =
    $sth->fetchall_arrayref({});
    $sth->finish();
    return $data;
}    # sub getborrowercategory

=head2 ethnicitycategories

  ($codes_arrayref, $labels_hashref) = &ethnicitycategories();

Looks up the different ethnic types in the database. Returns two
elements: a reference-to-array, which lists the ethnicity codes, and a
reference-to-hash, which maps the ethnicity codes to ethnicity
descriptions.

=cut

#'

sub ethnicitycategories {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("Select code,name from ethnicity order by name");
    $sth->execute;
    my %labels;
    my @codes;
    while ( my $data = $sth->fetchrow_hashref ) {
        push @codes, $data->{'code'};
        $labels{ $data->{'code'} } = $data->{'name'};
    }
    $sth->finish;
    return ( \@codes, \%labels );
}

=head2 fixEthnicity

  $ethn_name = &fixEthnicity($ethn_code);

Takes an ethnicity code (e.g., "european" or "pi") and returns the
corresponding descriptive name from the C<ethnicity> table in the
Koha database ("European" or "Pacific Islander").

=cut

#'

sub fixEthnicity {
    my $ethnicity = shift;
    return unless $ethnicity;
    my $dbh       = C4::Context->dbh;
    my $sth       = $dbh->prepare("Select name from ethnicity where code = ?");
    $sth->execute($ethnicity);
    my $data = $sth->fetchrow_hashref;
    $sth->finish;
    return $data->{'name'};
}    # sub fixEthnicity

=head2 GetAge

  $dateofbirth,$date = &GetAge($date);

this function return the borrowers age with the value of dateofbirth

=cut

#'
sub GetAge{
    my ( $date, $date_ref ) = @_;

    if ( not defined $date_ref ) {
        $date_ref = sprintf( '%04d-%02d-%02d', Today() );
    }

    my ( $year1, $month1, $day1 ) = split /-/, $date;
    my ( $year2, $month2, $day2 ) = split /-/, $date_ref;

    my $age = $year2 - $year1;
    if ( $month1 . $day1 > $month2 . $day2 ) {
        $age--;
    }

    return $age;
}    # sub get_age

=head2 get_institutions
  $insitutions = get_institutions();

Just returns a list of all the borrowers of type I, borrownumber and name

=cut

#'
sub get_institutions {
    my $dbh = C4::Context->dbh();
    my $sth =
      $dbh->prepare(
"SELECT borrowernumber,surname FROM borrowers WHERE categorycode=? ORDER BY surname"
      );
    $sth->execute('I');
    my %orgs;
    while ( my $data = $sth->fetchrow_hashref() ) {
        $orgs{ $data->{'borrowernumber'} } = $data;
    }
    $sth->finish();
    return ( \%orgs );

}    # sub get_institutions

=head2 add_member_orgs

  add_member_orgs($borrowernumber,$borrowernumbers);

Takes a borrowernumber and a list of other borrowernumbers and inserts them into the borrowers_to_borrowers table

=cut

#'
sub add_member_orgs {
    my ( $borrowernumber, $otherborrowers ) = @_;
    my $dbh   = C4::Context->dbh();
    my $query =
      "INSERT INTO borrowers_to_borrowers (borrower1,borrower2) VALUES (?,?)";
    my $sth = $dbh->prepare($query);
    foreach my $otherborrowernumber (@$otherborrowers) {
        $sth->execute( $borrowernumber, $otherborrowernumber );
    }
    $sth->finish();

}    # sub add_member_orgs

=head2 GetCities (OUEST-PROVENCE)

  ($id_cityarrayref, $city_hashref) = &GetCities();

Looks up the different city and zip in the database. Returns two
elements: a reference-to-array, which lists the zip city
codes, and a reference-to-hash, which maps the name of the city.
WHERE =>OUEST PROVENCE OR EXTERIEUR

=cut

sub GetCities {

    #my ($type_city) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = qq|SELECT cityid,city_zipcode,city_name 
        FROM cities 
        ORDER BY city_name|;
    my $sth = $dbh->prepare($query);

    #$sth->execute($type_city);
    $sth->execute();
    my %city;
    my @id;
    #    insert empty value to create a empty choice in cgi popup
    push @id, " ";
    $city{""} = "";
    while ( my $data = $sth->fetchrow_hashref ) {
        push @id, $data->{'city_zipcode'}."|".$data->{'city_name'};
        $city{ $data->{'city_zipcode'}."|".$data->{'city_name'} } = $data->{'city_name'};
    }

#test to know if the table contain some records if no the function return nothing
    my $id = @id;
    $sth->finish;
    if ( $id == 1 ) {
        # all we have is the one blank row
        return ();
    }
    else {
        unshift( @id, "" );
        return ( \@id, \%city );
    }
}

=head2 GetSortDetails (OUEST-PROVENCE)

  ($lib) = &GetSortDetails($category,$sortvalue);

Returns the authorized value  details
C<&$lib>return value of authorized value details
C<&$sortvalue>this is the value of authorized value 
C<&$category>this is the value of authorized value category

=cut

sub GetSortDetails {
    my ( $category, $sortvalue ) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = qq|SELECT lib 
        FROM authorised_values 
        WHERE category=?
        AND authorised_value=? |;
    my $sth = $dbh->prepare($query);
    $sth->execute( $category, $sortvalue );
    my $lib = $sth->fetchrow;
    return ($lib) if ($lib);
    return ($sortvalue) unless ($lib);
}

=head2 MoveMemberToDeleted

  $result = &MoveMemberToDeleted($borrowernumber);

Copy the record from borrowers to deletedborrowers table.

=cut

# FIXME: should do it in one SQL statement w/ subquery
# Otherwise, we should return the @data on success

sub MoveMemberToDeleted {
    my ($member) = shift or return;
    my $dbh = C4::Context->dbh;
    my $query = qq|SELECT * 
          FROM borrowers 
          WHERE borrowernumber=?|;
    my $sth = $dbh->prepare($query);
    $sth->execute($member);
    #my @data = $sth->fetchrow_array;
   my $row = $sth->fetchrow_hashref();
   return unless $row;
   delete($$row{password_plaintext});
   $sth = $dbh->prepare(sprintf("INSERT INTO deletedborrowers(%s) VALUES(%s)",
         join(',', keys %$row),
         join(',', map { '?' } keys %$row)
      )
   );
   $sth->execute(values %$row) || die $dbh->errstr();

 #   (@data) or return;  # if we got a bad borrowernumber, there's nothing to insert
 #   $sth =
 #     $dbh->prepare( "INSERT INTO deletedborrowers VALUES ("
 #         . ( "?," x ( scalar(@data) - 1 ) )
 #         . "?)" );
 #   $sth->execute(@data);
}

=head2 DelMember

DelMember($borrowernumber);

This function remove directly a borrower whitout writing it on deletedborrower.
+ Deletes reserves for the borrower

=cut

sub DelMember {
    my $dbh            = C4::Context->dbh;
    my $borrowernumber = shift;
    #warn "in delmember with $borrowernumber";
    return unless $borrowernumber;    # borrowernumber is mandatory.

    my $query = qq|DELETE 
          FROM  reserves 
          WHERE borrowernumber=?|;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    $sth->finish;
    $sth = $dbh->prepare('DELETE
      FROM borrower_worklibrary
     WHERE borrowernumber = ?');
    $sth->execute($borrowernumber);
    $query = "
       DELETE
       FROM borrowers
       WHERE borrowernumber = ?
   ";
    $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    $sth->finish;
    logaction("MEMBERS", "DELETE", $borrowernumber, "") if C4::Context->preference("BorrowersLog");
    return $sth->rows;
}

=head2 ExtendMemberSubscriptionTo (OUEST-PROVENCE)

    $date = ExtendMemberSubscriptionTo($borrowerid, $date);

Extending the subscription to a given date or to the expiry date calculated on ISO date.
Returns ISO date.

=cut

sub ExtendMemberSubscriptionTo {
    my ( $borrowerid,$date) = @_;
    my $dbh = C4::Context->dbh;
    my $borrower = GetMember($borrowerid,'borrowernumber');
    unless ($date){
      $date=POSIX::strftime("%Y-%m-%d",localtime());
      my $borrower = GetMember($borrowerid,'borrowernumber');
      $date = GetExpiryDate( $borrower->{'categorycode'}, $date );
    }
    my $sth = $dbh->do(<<EOF);
UPDATE borrowers 
SET  dateexpiry='$date' 
WHERE borrowernumber='$borrowerid'
EOF
    # add enrolmentfee if needed
    $sth = $dbh->prepare("SELECT enrolmentfee FROM categories WHERE categorycode=?");
    $sth->execute($borrower->{'categorycode'});
    my ($enrolmentfee) = $sth->fetchrow;
    if ($enrolmentfee && $enrolmentfee > 0) {
        # insert fee in patron debts
        C4::Accounts::manualinvoice(
         borrowernumber => $borrower->{'borrowernumber'},
         accounttype    => 'A', 
         amount         => $enrolmentfee
        );
    }
    return $date if ($sth);
    return 0;
}

=head2 GetRoadTypes (OUEST-PROVENCE)

  ($idroadtypearrayref, $roadttype_hashref) = &GetRoadTypes();

Looks up the different road type . Returns two
elements: a reference-to-array, which lists the id_roadtype
codes, and a reference-to-hash, which maps the road type of the road .

=cut

sub GetRoadTypes {
    my $dbh   = C4::Context->dbh;
    my $query = qq|
SELECT roadtypeid,road_type 
FROM roadtype 
ORDER BY road_type|;
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my %roadtype;
    my @id;

    #    insert empty value to create a empty choice in cgi popup

    while ( my $data = $sth->fetchrow_hashref ) {

        push @id, $data->{'roadtypeid'};
        $roadtype{ $data->{'roadtypeid'} } = $data->{'road_type'};
    }

#test to know if the table contain some records if no the function return nothing
    my $id = @id;
    $sth->finish;
    if ( $id eq 0 ) {
        return ();
    }
    else {
        unshift( @id, "" );
        return ( \@id, \%roadtype );
    }
}



=head2 GetTitles (OUEST-PROVENCE)

  ($borrowertitle)= &GetTitles();

Looks up the different title . Returns array  with all borrowers title

=cut

sub GetTitles {
    my @borrowerTitle = split /,|\|/,C4::Context->preference('BorrowersTitles');
    unshift( @borrowerTitle, "" );
    my $count=@borrowerTitle;
    if ($count == 1){
        return ();
    }
    else {
        return ( \@borrowerTitle);
    }
}

=head2 GetPatronImage

    my ($imagedata, $dberror) = GetPatronImage($cardnumber);

Returns the mimetype and binary image data of the image for the patron with the supplied cardnumber.

=cut

sub GetPatronImage {
    my ($cardnumber) = @_;
    warn "Cardnumber passed to GetPatronImage is $cardnumber" if $debug;
    my $dbh = C4::Context->dbh;
    my $query = 'SELECT mimetype, imagefile FROM patronimage WHERE cardnumber = ?';
    my $sth = $dbh->prepare($query);
    $sth->execute($cardnumber);
    my $imagedata = $sth->fetchrow_hashref;
    warn "Database error!" if $sth->errstr;
    return $imagedata, $sth->errstr;
}

=head2 PutPatronImage

    PutPatronImage(
      cardnumber => $cardnumber, 
      mimetype   => $mimetype
      imgfile    => $imgfile
    );

Stores patron binary image data and mimetype in database.
NOTE: This function is good for updating images as well as inserting new images in the database.

=cut

sub PutPatronImage 
{
    my %g = @_;
    my $dbh = C4::Context->dbh;
    my $query = "INSERT INTO patronimage (cardnumber, mimetype, imagefile) 
      VALUES (?,?,?) 
      ON DUPLICATE KEY UPDATE imagefile = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute(
      $g{cardnumber},
      $g{mimetype},
      $g{imgfile},
      $g{imgfile},
   );
   return $sth->errstr;
}

=head2 RmPatronImage

    my ($dberror) = RmPatronImage($cardnumber);

Removes the image for the patron with the supplied cardnumber.

=cut

sub RmPatronImage {
    my ($cardnumber) = @_;
    warn "Cardnumber passed to GetPatronImage is $cardnumber" if $debug;
    my $dbh = C4::Context->dbh;
    my $query = "DELETE FROM patronimage WHERE cardnumber = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute($cardnumber);
    my $dberror = $sth->errstr;
    warn "Database error!" if $sth->errstr;
    return $dberror;
}

=head2 GetRoadTypeDetails (OUEST-PROVENCE)

  ($roadtype) = &GetRoadTypeDetails($roadtypeid);

Returns the description of roadtype
C<&$roadtype>return description of road type
C<&$roadtypeid>this is the value of roadtype s

=cut

sub GetRoadTypeDetails {
    my ($roadtypeid) = @_;
    my $dbh          = C4::Context->dbh;
    my $query        = qq|
SELECT road_type 
FROM roadtype 
WHERE roadtypeid=?|;
    my $sth = $dbh->prepare($query);
    $sth->execute($roadtypeid);
    my $roadtype = $sth->fetchrow;
    return ($roadtype);
}

=head2 GetBorrowersWhoHaveNotBorrowedSince

&GetBorrowersWhoHaveNotBorrowedSince($date)

this function get all borrowers who haven't borrowed since the date given on input arg.
      
=cut

sub GetBorrowersWhoHaveNotBorrowedSince {
### TODO : It could be dangerous to delete Borrowers who have just been entered and who have not yet borrowed any book. May be good to add a dateexpiry or dateenrolled filter.      
       
                my $filterdate = shift||POSIX::strftime("%Y-%m-%d",localtime());
    my $filterbranch = shift || 
                        ((C4::Context->preference('IndependantBranches') 
                             && C4::Context->userenv 
                             && C4::Context->userenv->{flags} % 2 !=1 
                             && C4::Context->userenv->{branch})
                         ? C4::Context->userenv->{branch}
                         : "");  
    my $dbh   = C4::Context->dbh;
    my $query = "
        SELECT borrowers.borrowernumber,max(issues.timestamp) as latestissue
        FROM   borrowers
        JOIN   categories USING (categorycode)
        LEFT JOIN issues ON borrowers.borrowernumber = issues.borrowernumber
        WHERE  category_type <> 'S'
   ";
    my @query_params;
    if ($filterbranch && $filterbranch ne ""){ 
        $query.=" AND borrowers.branchcode= ?";
        push @query_params,$filterbranch;
    }    
    $query.=" GROUP BY borrowers.borrowernumber";
    if ($filterdate){ 
        $query.=" HAVING latestissue <? OR latestissue IS NULL";
        push @query_params,$filterdate;
    }
    warn $query if $debug;
    my $sth = $dbh->prepare($query);
    if (scalar(@query_params)>0){  
        $sth->execute(@query_params);
    } 
    else {
        $sth->execute;
    }      
    
    my @results;
    while ( my $data = $sth->fetchrow_hashref ) {
        push @results, $data;
    }
    return \@results;
}

=head2 GetBorrowersWhoHaveNeverBorrowed

$results = &GetBorrowersWhoHaveNeverBorrowed

this function get all borrowers who have never borrowed.

I<$result> is a ref to an array which all elements are a hasref.

=cut

sub GetBorrowersWhoHaveNeverBorrowed {
    my $filterbranch = shift || 
                        ((C4::Context->preference('IndependantBranches') 
                             && C4::Context->userenv 
                             && C4::Context->userenv->{flags} % 2 !=1 
                             && C4::Context->userenv->{branch})
                         ? C4::Context->userenv->{branch}
                         : "");  
    my $dbh   = C4::Context->dbh;
    my $query = "
        SELECT borrowers.borrowernumber,max(timestamp) as latestissue
        FROM   borrowers
          LEFT JOIN issues ON borrowers.borrowernumber = issues.borrowernumber
        WHERE issues.borrowernumber IS NULL
   ";
    my @query_params;
    if ($filterbranch && $filterbranch ne ""){ 
        $query.=" AND borrowers.branchcode= ?";
        push @query_params,$filterbranch;
    }
    warn $query if $debug;
  
    my $sth = $dbh->prepare($query);
    if (scalar(@query_params)>0){  
        $sth->execute(@query_params);
    } 
    else {
        $sth->execute;
    }      
    
    my @results;
    while ( my $data = $sth->fetchrow_hashref ) {
        push @results, $data;
    }
    return \@results;
}

=head2 GetBorrowersWithIssuesHistoryOlderThan

$results = &GetBorrowersWithIssuesHistoryOlderThan($date)

this function get all borrowers who has an issue history older than I<$date> given on input arg.

I<$result> is a ref to an array which all elements are a hashref.
This hashref is containt the number of time this borrowers has borrowed before I<$date> and the borrowernumber.

=cut

sub GetBorrowersWithIssuesHistoryOlderThan {
    my $dbh  = C4::Context->dbh;
    my $date = shift ||POSIX::strftime("%Y-%m-%d",localtime());
    my $filterbranch = shift || 
                        ((C4::Context->preference('IndependantBranches') 
                             && C4::Context->userenv 
                             && C4::Context->userenv->{flags} % 2 !=1 
                             && C4::Context->userenv->{branch})
                         ? C4::Context->userenv->{branch}
                         : "");  
    my $query = "
       SELECT count(borrowernumber) as n,borrowernumber
       FROM old_issues
       WHERE returndate < ?
         AND borrowernumber IS NOT NULL 
    "; 
    my @query_params;
    push @query_params, $date;
    if ($filterbranch){
        $query.="   AND branchcode = ?";
        push @query_params, $filterbranch;
    }    
    $query.=" GROUP BY borrowernumber ";
    warn $query if $debug;
    my $sth = $dbh->prepare($query);
    $sth->execute(@query_params);
    my @results;

    while ( my $data = $sth->fetchrow_hashref ) {
        push @results, $data;
    }
    return \@results;
}

=head2 GetBorrowersNamesAndLatestIssue

$results = &GetBorrowersNamesAndLatestIssueList(@borrowernumbers)

this function get borrowers Names and surnames and Issue information.

I<@borrowernumbers> is an array which all elements are borrowernumbers.
This hashref is containt the number of time this borrowers has borrowed before I<$date> and the borrowernumber.

=cut

sub GetBorrowersNamesAndLatestIssue {
    my $dbh  = C4::Context->dbh;
    my @borrowernumbers=@_;  
    my $query = "
       SELECT surname,lastname, phone, email,max(timestamp)
       FROM borrowers 
         LEFT JOIN issues ON borrowers.borrowernumber=issues.borrowernumber
       GROUP BY borrowernumber
   ";
    my $sth = $dbh->prepare($query);
    $sth->execute;
    my $results = $sth->fetchall_arrayref({});
    return $results;
}

=head2 DebarMember

=over 4

my $success = DebarMember( $borrowernumber );

marks a Member as debarred, and therefore unable to checkout any more
items.

return :
true on success, false on failure

=back

=cut

sub DebarMember {
    my $borrowernumber = shift;

    return unless defined $borrowernumber;
    return unless $borrowernumber =~ /^\d+$/;

    return ModMember( borrowernumber => $borrowernumber,
                      debarred       => 1 );
    
}

=head2 AddMessage

=over 4

AddMessage( $borrowernumber, $message_type, $message, $branchcode, $staffnumber );

Adds a message to the messages table for the given borrower.

Returns:
  True on success
  False on failure

=back

=cut

sub AddMessage {
    my ( $borrowernumber, $message_type, $message, $branchcode, $staffnumber, $checkout_display ) = @_;

    my $dbh  = C4::Context->dbh;

    if ( ! ( $borrowernumber && $message_type && $message && $branchcode ) ) {
      return;
    }

    my $query = "SELECT * FROM authorised_values WHERE category = 'BOR_NOTES'";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $auth_val;
    while (my $row = $sth->fetchrow_hashref) {
      if ($row->{lib} eq $message) {
        $auth_val = $row->{authorised_value};
        last;
      }
    }

    if ($auth_val) {
      $query = "INSERT INTO messages ( borrowernumber, branchcode, message_type, message, staffnumber, auth_value, checkout_display ) VALUES ( ?, ?, ?, ?, ?, ?,? )";
      $sth = $dbh->prepare($query);
      $sth->execute( $borrowernumber, $branchcode, $message_type, $message, $staffnumber, $auth_val, $checkout_display );
    }
    else {
      $query = "INSERT INTO messages ( borrowernumber, branchcode, message_type, message, staffnumber, checkout_display ) VALUES ( ?, ?, ?, ?, ?, ?)";
      $sth = $dbh->prepare($query);
      $sth->execute( $borrowernumber, $branchcode, $message_type, $message, $staffnumber, $checkout_display );
    }

    return 1;
}

=head2 GetMessages

=over 4

GetMessages( $borrowernumber, $type );

$type is message type, B for borrower, or L for Librarian.
Empty type returns all messages of any type.

Returns all messages for the given borrowernumber

=back

=cut

sub GetMessages {
    my ( $borrowernumber, $type, $branchcode ) = @_;
    $type //= '%';

    my $query = "SELECT
                  branches.branchname,
                  messages.*,
                  DATE_FORMAT( message_date, '%m/%d/%Y' ) AS message_date_formatted,
                  messages.branchcode = ? AS can_delete
                  FROM messages, branches
                  WHERE borrowernumber = ?
                  AND message_type LIKE ?
                  AND messages.branchcode = branches.branchcode
                  AND checkout_display = 1
                  ORDER BY message_date DESC";
    return C4::Context->dbh->selectall_arrayref(
        $query, {Slice=>{}}, $branchcode, $borrowernumber, $type);
}

=head2 GetMessages

=over 4

GetMessagesCount( $borrowernumber, $type );

$type is message type, B for borrower, or L for Librarian.
Empty type returns all messages of any type.

Returns the number of messages for the given borrowernumber

=back

=cut

sub GetMessagesCount {
    my ( $borrowernumber, $type, $branchcode ) = @_;

    if ( ! $type ) {
      $type = '%';
    }

    my $dbh  = C4::Context->dbh;

    my $query = "SELECT COUNT(*) as MsgCount FROM messages WHERE borrowernumber = ? AND message_type LIKE ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $borrowernumber, $type ) ;
    my @results;

    my $data = $sth->fetchrow_hashref;
    my $count = $data->{'MsgCount'};

    return $count;
}



=head2 DeleteMessage

=over 4

DeleteMessage( $message_id, $staffnumber );

=back

=cut

sub DeleteMessage {

    my ( $message_id, $staffnumber ) = @_;

    my $dbh = C4::Context->dbh;

    my $query = "UPDATE messages
                   SET checkout_display = 0
                   WHERE message_id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $message_id );

    $query = "SELECT * FROM messages
                WHERE message_id = ?";
    $sth = $dbh->prepare($query);
    $sth->execute( $message_id );

    my $message = $sth->fetchrow_hashref;
    if ($message->{auth_value} =~ /^B_/) {
      AddMessage($message->{borrowernumber},$message->{message_type},'Unblocked',$message->{branchcode},$staffnumber,0);
    }

}

=head2 SetDisableReadingHistory

=over 4

SetDisableReadingHistory( $status, $borrowernumber );

=back

=cut

sub SetDisableReadingHistory {

    my ( $status, $borrowernumber ) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "UPDATE borrowers
                   SET disable_reading_history = ?
                   WHERE borrowernumber = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $status, $borrowernumber );

    return;

}

=head SearchMemberAdvanced
  ( $count, $results ) = SearchMemberAdvanced({ 
    [ param => $param, ]
  });
=cut

sub SearchMemberAdvanced {
  my ( $params ) = @_;
#  warn Data::Dumper::Dumper( $params );
      
  my $orderby = $params->{'orderby'} || 'borrowers.surname';
  
  my $sql = "SELECT COUNT(*) FROM borrowers "
          . "LEFT JOIN categories ON borrowers.categorycode = categories.categorycode ";
  my @limits     = ();
  my @sql_params = ();
  if ( defined $params->{'categorycode'} ) {
    push( @limits, "categories.categorycode = ?" );
    push( @sql_params, $params->{'categorycode'} );
  }

  if ( defined $params->{'borrowernumber'} ) {
    push( @limits, "borrowers.borrowernumber = ?" );
    push( @sql_params, $params->{'borrowernumber'} );
  }
  
   if ( defined $params->{'cardnumber'} ) {
      my @in = @{_prefix_cardnum_multibranch($$params{cardnumber})};
      push(@limits, 
         sprintf(
            "borrowers.cardnumber IN(%s)", 
            join(',',map{'?'}@in)
         )
      );
      push( @sql_params, @in );
  }
  

  if ( defined $params->{'dateenrolled_after'} ) {
    push( @limits, "borrowers.dateenrolled >= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateenrolled_after'})->output("iso") );
  }

  if ( defined $params->{'dateenrolled_before'} ) {
    push( @limits, "borrowers.dateenrolled <= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateenrolled_before'})->output("iso") );
  }

  if ( defined $params->{'dateexpiry_after'} ) {
    push( @limits, "borrowers.dateexpiry >= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateexpiry_after'})->output("iso") );
  }

  if ( defined $params->{'dateexpiry_before'} ) {
    push( @limits, "borrowers.dateexpiry <= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateexpiry_before'})->output("iso") );
  }

  if ( defined $params->{'branchcode'} ) {
    push( @limits, "borrowers.branchcode = ?" );
    push( @sql_params, $params->{'branchcode'} );
  }

  if ( defined $params->{'sort1'} ) {
    push( @limits, "borrowers.sort1 = ?" );
    push( @sql_params, $params->{'sort1'} );
  }

  if ( defined $params->{'sort2'} ) {
    push( @limits, "borrowers.sort2 = ?" );
    push( @sql_params, $params->{'sort2'} );
  }

  if ( defined $params->{'userid'} ) {
    push( @limits, "borrowers.userid = ?" );
    push( @sql_params, $params->{'userid'} );
  }

  if ( defined $params->{'dateofbirth_after'} ) {
    push( @limits, "borrowers.dateofbirth >= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateofbirth_after'})->output("iso") );
  }

  if ( defined $params->{'dateofbirth_before'} ) {
    push( @limits, "borrowers.dateofbirth <= DATE(?)" );
    push( @sql_params, C4::Dates->new($params->{'dateofbirth_before'})->output("iso") );
  }

  if ( defined $params->{'surname'} ) {
    push( @limits, "borrowers.surname LIKE ?" );
    push( @sql_params, "$params->{'surname'}%" );
  }

  if ( defined $params->{'firstname'} ) {
    push( @limits, "borrowers.firstname LIKE ?" );
    push( @sql_params, "$params->{'firstname'}%" );
  }

  if ( defined $params->{'address'} ) {
    push( @limits, "borrowers.address LIKE ?" );
    push( @sql_params, "%$params->{'address'}%" );
  }

  if ( defined $params->{'city'} ) {
    push( @limits, "( borrowers.city LIKE ? OR borrowers.city LIKE ? )" );
    if ( $params->{'city'} ) {
      push( @sql_params, "%$params->{'city'}" );
      push( @sql_params, "$params->{'city'}%" );
    } else {
      push( @sql_params, '' );
      push( @sql_params, '' );
    }
  }

  if ( defined $params->{'zipcode'} ) {
    push( @limits, "borrowers.zipcode = ?" );
    push( @sql_params, $params->{'zipcode'} );
  }

  if ( defined $params->{'B_address'} ) {
    push( @limits, "borrowers.B_address LIKE ?" );
    push( @sql_params, "%$params->{'B_address'}%" );
  }

  if ( defined $params->{'B_city'} ) {
    push( @limits, "( borrowers.B_city LIKE ? OR borrowers.B_city LIKE ? )" );
    if ( $params->{'B_city'} ) {
      push( @sql_params, "%$params->{'B_city'}" );
      push( @sql_params, "$params->{'B_city'}%" );
    } else {
      push( @sql_params, '' );
      push( @sql_params, '' );
    }
  }

  if ( defined $params->{'B_zipcode'} ) {
    push( @limits, "borrowers.B_zipcode = ?" );
    push( @sql_params, $params->{'B_zipcode'} );
  }

  if ( defined $params->{'email'} ) {
    push( @limits, "( borrowers.email LIKE ? OR borrowers.email LIKE ? )" );
    if ( $params->{'email'} ) {
      push( @sql_params, "%$params->{'email'}" );
      push( @sql_params, "$params->{'email'}%" );
    } else {
      push( @sql_params, '' );
      push( @sql_params, '' );
    }
  }

  if ( defined $params->{'emailpro'} ) {
    push( @limits, "( borrowers.emailpro LIKE ? OR borrowers.emailpro LIKE ? )" );
    if ( $params->{'emailpro'} ) {
      push( @sql_params, "%$params->{'emailpro'}" );
      push( @sql_params, "$params->{'emailpro'}%" );
    } else {
      push( @sql_params, '' );
      push( @sql_params, '' );
    }
  }

  if ( defined $params->{'phone'} ) {
    push( @limits, "( borrowers.phone LIKE ? OR borrowers.phone LIKE ? )" );
    if ( $params->{'phone'} ) {
      push( @sql_params, "%$params->{'phone'}" );
      push( @sql_params, "$params->{'phone'}%" );
    } else {
      push( @sql_params, '' );
      push( @sql_params, '' );
    }
  }

  if ( defined $params->{'opacnotes'} ) {
    push( @limits, "borrowers.opacnotes LIKE ?" );
    push( @sql_params, "%$params->{'opacnotes'}%" );
  }

  if ( defined $params->{'borrowernotes'} ) {
    push( @limits, "borrowers.borrowernotes LIKE ?" );
    push( @sql_params, "%$params->{'borrowernotes'}%" );
  }

  if ( defined $params->{'debarred'} ) {
    push( @limits, "borrowers.debarred = ?" );
    push( @sql_params, $params->{'debarred'} );
  }

  if ( defined $params->{'gonenoaddress'} ) {
    push( @limits, "borrowers.gonenoaddress = ?" );
    push( @sql_params, $params->{'gonenoaddress'} );
  }

  if ( defined $params->{'lost'} ) {
    push( @limits, "borrowers.lost = ?" );
    push( @sql_params, $params->{'lost'} );
  }

  if ( defined $params->{'list_id'} ) {
    my $list_sql = "borrowers.borrowernumber IN ( SELECT borrowernumber FROM borrower_lists_tracking WHERE list_id = ? )";
    push( @limits, $list_sql );
    push( @sql_params, $params->{'list_id'} );
  }

  if ( defined $params->{'attributes'} ) {
    my $attributes = $params->{'attributes'};
    
    foreach my $key ( keys %$attributes ) {
      push( @limits , "borrowernumber IN ( 
                        SELECT borrowernumber FROM borrower_attributes 
                        JOIN borrower_attribute_types USING ( code )
                        WHERE code = ? AND attribute LIKE ? 
                      )"
      );
      push( @sql_params, $key );
      push( @sql_params, $attributes->{$key} );                                                                                                                
    }
  }
  
  my $limits = join( ' AND ', @limits );
  if ($limits) { $sql .= " WHERE $limits "; }
  ($sql, @sql_params) = _constrain_sql_by_branchcategory($sql, @sql_params);
  my $dbh = C4::Context->dbh;
  my $sth = $dbh->prepare( $sql );
  $sth->execute( @sql_params );
  my $cnt = ($sth->fetchrow_array)[0];

  $sql =~ s/COUNT\(\*\)/\*/s;
  $sql .= " ORDER BY $orderby ";
  $$params{offset} ||= 0;
  $$params{limit}  ||= 20;
  $sql .= " LIMIT $$params{offset},$$params{limit}";

  $sth = $dbh->prepare($sql);
  $sth->execute(@sql_params);
  my $data = $sth->fetchall_arrayref({});
  return ( $cnt, $data );
}

=head2 _prefix_cardnum

=over 4

$cardnum = _prefix_cardnum(
   cardnumber           => $cardnumber,
  [branchcode           => $branchcode,]
  [patronbarcodeprefix  => $prefix,]
  [prefix               => $prefix,]
);

If a system-wide barcode length is defined, and a prefix defined for the 
passed branch or the user's branch, modify the barcode by prefixing and padding.
Uses logged in user's active branch if $branchcode is not passed in.
The parameter 'prefix' is a synonymn for 'patronbarcodeprefix' if you don't 
feel like typing.

=back
=cut

sub _prefix_cardnum_multibranch
{
    my $str = shift;
    my @all;
    for my $branch (values %{C4::Branch::GetAllBranches()}) {
        ## relax this
        #die "No patronbarcodeprefix set for branch $branch->{branchcode} in table branches"
        #   unless $branch->{patronbarcodeprefix};
        #####
        unless ($branch->{patrongbarcodeprefix}) {
            push @all, $str;
        }
        else {
            push @all, _prefix_cardnum(
                cardnumber           => $str,
                branchcode           => $branch->{branchcode},
                patronbarcodeprefix  => $branch->{patronbarcodeprefix},
                );
        }
    }
    return \@all // [];
}

sub _prefix_cardnum
{
   my %g = @_;
   my $pbclen = C4::Context->preference('patronbarcodelength');
   if($pbclen && (length($g{cardnumber}) < $pbclen)) {
      #if we have a system-wide cardnum length and a branch prefix, prepend the prefix.
      if(!$g{branchcode} && defined(C4::Context->userenv) ) {
         $g{branchcode} = C4::Context->userenv->{'branch'};
      }
      return $g{cardnumber} unless $g{branchcode};
      my $prefix = $g{patronbarcodeprefix} || $g{prefix} || 0;
      unless ($prefix) {
         my $branch = GetBranchDetail($g{branchcode}) // {};
         return $g{cardnumber} unless $$branch{patronbarcodeprefix};
      }
      my $padding = $pbclen - length($prefix) - length($g{cardnumber});
      $g{cardnumber} = $prefix . '0' x $padding . $g{cardnumber} if($padding >= 0);
   }
   return $g{cardnumber};
}

END { }    # module clean-up code here (global destructor)

1;

__END__

=head1 AUTHOR

Koha Team

=cut
