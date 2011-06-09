package C4::Members::Lists;

# Copyright 2010 Kyle M Hall <kyle@kylehall.info>
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

use Koha;
use C4::Context;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	# set the version for version checking
	$VERSION = 3.01;
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw(
	    &CreateList
	    &DeleteList
	    
	    &GetLists
	    &GetList
	    
	    &AddBorrowerToList
	    &RemoveBorrowerFromList
	    
	    &GetListsForMember
	    
	    &GetListMembers
	    
	    &ModifyListMembers
	);
}

=head1 NAME

C4::Members::Lists - Module to store, retrieve, and modify lists of borrowers.

=head1 SYNOPSIS

  use C4::Members::Lists;

=head1 DESCRIPTION

The module handles creating and modifying lists of borrowers.

=head1 FUNCTIONS

=over 2

=item CreateList

  CreateList({
      list_name => $list_name,
      [ list_owner => $borrowernumber ]
  });

Creates a new list for the given user. If the list owner
is not specified, the function will attempt to use the
currently logged in user as the list owner.

=cut

sub CreateList {
    my ( $params ) = @_;
    my $list_name = $params->{'list_name'};
    my $list_owner = $params->{'list_owner'};
    
    return unless ( $list_name );
    my $dbh = C4::Context->dbh;
    my $sth;
    
    unless ( $list_owner ) {
        my $userenv = C4::Context->userenv();
        $list_owner = ( ref($userenv) eq 'HASH' ) ? $userenv->{'number'} : '0';
    }

    ## dupecheck
    $sth = $dbh->prepare('SELECT *
      FROM borrower_lists
     WHERE list_name = ?');
    $sth->execute($list_name);
    my $row = $sth->fetchrow_hashref() // {};
    my $list_id;
    if ($$row{list_id} && ($list_owner ne $$row{list_owner})) {
      $sth = $dbh->prepare('
         UPDATE borrower_lists
            SET list_owner = ?
          WHERE list_id    = ?');
      $sth->execute($list_owner,$$row{list_id});
      $list_id = $$row{list_id};
    }
    elsif ($$row{list_id}) {
      # do nothing
    }
    else {
      my $sql = "INSERT INTO borrower_lists ( list_name, list_owner ) VALUES ( ?, ? )";
      $sth = $dbh->prepare( $sql );
      $sth->execute( $list_name, $list_owner );
      $list_id = $dbh->{ q{mysql_insertid} };
    }
    return $list_id;
}

=item DeleteList

  DeleteList({
      list_id => $list_id,
  });

=cut

sub DeleteList {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    
    return unless ( $list_id );

    my $dbh = C4::Context->dbh;
    
    my $sql = "DELETE FROM borrower_lists_tracking WHERE list_id = ?";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $list_id );

    $sql = "DELETE FROM borrower_lists WHERE list_id = ?";
    $sth = $dbh->prepare( $sql );
    $sth->execute( $list_id );
}

=item GetLists

  my $lists = GetLists({
     [ list_owner => $borrowernumber, ]
     [ selected => $list_id, ]
     [ with_count => 1, ]
  });

  Returns an arrayref of hashrefs of the lists
  owned by the given user.

  If param 'selected' is passed, the hashref for
  the given id will have the key 'selected' set
  to true.
  
  If param 'with_count' is passed, the hashref for
  each list will contain the key 'count' which
  will give the number of borrowers on that list.
=cut

sub GetLists {
    my ( $params ) = @_;
    my $list_owner = $params->{'list_owner'};
    my $selected   = $params->{'selected'};
    my $with_count = $params->{'with_count'};
    
    unless ( $list_owner ) {
        my $userenv = C4::Context->userenv();
        $list_owner = ( ref($userenv) eq 'HASH' ) ? $userenv->{'number'} : '0';
    }
    
    my $sql = "SELECT * FROM borrower_lists WHERE list_owner = ?";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $list_owner );
    
    my $lists = $sth->fetchall_arrayref({});

    if ( $selected || $with_count ) {
      foreach my $l ( @$lists ) {
        $l->{'selected'} = 1 if ( $l->{'list_id'} eq $selected );
        $l->{'count'} = GetListMembersCount({ list_id => $l->{'list_id'} }) if ( $with_count );
      }
    }

    return $lists;
}

=item GetList

  my $list = GetList({
    list_id => $list_id
  });

  Returns a hashref of the list.

=cut

sub GetList {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    
    return unless ( $list_id );
        
    my $sql = "SELECT * FROM borrower_lists WHERE list_id = ?";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $list_id );
    
    my $list = $sth->fetchrow_hashref();

    return $list;
}

=item AddBorrowerToList

  AddBorrowerToList({
      list_id => $list_id,
      borrowernumber => $borrowernumber
  });

  Adds a borrower to the given list
=cut

sub AddBorrowerToList {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    my $borrowernumber = $params->{'borrowernumber'};
    
    return unless ( $list_id && $borrowernumber );
    my $dbh = C4::Context->dbh;
    my $sth;

    ## dupecheck
    $sth = $dbh->prepare('SELECT 1 FROM borrower_lists_tracking
      WHERE list_id        = ?
        AND borrowernumber = ?');
    $sth->execute($list_id,$borrowernumber);
    my $dupe = ($sth->fetchrow_array)[0];
    return 1 if $dupe;
    
    my $sql = "INSERT INTO borrower_lists_tracking ( list_id, borrowernumber ) VALUES ( ?, ? )";
    $sth = $dbh->prepare( $sql );
    return $sth->execute( $list_id, $borrowernumber );
}

=item RemoveBorrowerFromList

  RemoveBorrowerFromList({
      list_id => $list_id,
      borrowernumber => $borrowernumber
  });

  Removes a borrower from the given list
=cut

sub RemoveBorrowerFromList {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    my $borrowernumber = $params->{'borrowernumber'};
    
    return unless ( $list_id && $borrowernumber );
    
    my $sql = "DELETE FROM borrower_lists_tracking WHERE list_id = ? AND borrowernumber = ?";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    return $sth->execute( $list_id, $borrowernumber );
}

=item GetListMembersCount

  my $count = GetListMembersCount({
      list_id => $list_id,
  });

=cut

sub GetListMembersCount {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    
    return unless ( $list_id );
    
    my $sql = "SELECT COUNT(*) AS members_count FROM borrower_lists_tracking WHERE list_id = ?";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $list_id );
    
    my $row = $sth->fetchrow_hashref();
    return $row->{'members_count'}
}

=item GetListsForMember

  my @$list = GetListsForMember({
      borrowernumber => $borrowernumber,
      [ list_owner => $list_owner, ]
  });

=cut

sub GetListsForMember {
    my ( $params ) = @_;
    my $borrowernumber = $params->{'borrowernumber'};
    my $list_owner = $params->{'list_owner'};
    
    return unless ( $borrowernumber );

    unless ( $list_owner ) {
        my $userenv = C4::Context->userenv();
        $list_owner = ( ref($userenv) eq 'HASH' ) ? $userenv->{'number'} : '0';
    }
    
    my $sql = "SELECT * FROM borrower_lists_tracking LEFT JOIN borrower_lists ON borrower_lists_tracking.list_id = borrower_lists.list_id
               WHERE borrower_lists_tracking.borrowernumber = ? AND borrower_lists.list_owner = ?";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $borrowernumber, $list_owner );
    
    my $lists = $sth->fetchall_arrayref({});

    return $lists;
}

=item GetListMembers

  my @$members = GetListMembers({
    list_id => $list_id
  });

=cut

sub GetListMembers {
    my ( $params ) = @_;
    my $list_id = $params->{'list_id'};
    
    return unless ( $list_id );

    my $sql  = "
      SELECT * FROM borrowers 
      WHERE borrowers.borrowernumber IN 
      ( SELECT borrower_lists_tracking.borrowernumber FROM borrower_lists_tracking WHERE list_id = ? )
    ";
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $list_id );
    
    my $lists = $sth->fetchall_arrayref({});

    return $lists;
}

=item ModifyListMembers

  my $members_affected = ModifyListMembers({
      list_id        => $list_id,
      column         => $column,
      find_value     => $find_value,
      [ replace_with => $replace_with, ]
      [ delete       => 1, ]
      [ test_only    => 1, ]
  });

=cut

sub ModifyListMembers {
    my ( $params ) = @_;
    my $list_id      = $params->{'list_id'};
    my $column       = $params->{'column'};
    my $find_value   = $params->{'find_value'};
    my $replace_with = $params->{'replace_with'};
    my $delete       = $params->{'delete'};
    my $test_only    = $params->{'test_only'};
    
    return unless ( $list_id && $column && $find_value && ( $replace_with || $delete ) );

    my $what_sql  = "SELECT * FROM borrowers ";
    my $where_sql = "
      WHERE 
        ? LIKE ? 
      AND 
        borrowers.borrowernumber IN 
          ( SELECT borrower_lists_tracking.borrowernumber FROM borrower_lists_tracking WHERE list_id = ? )
    ";
    
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( $what_sql . $where_sql );
    my $rows_affected = $sth->execute( $column, $find_value, $list_id );    
    my $borrowers = $sth->fetchall_arrayref({});
    
    my @sql_params;
    
    if ( $test_only ) {
      foreach my $b ( @$borrowers ) {
        
      }
    }
    elsif ( $replace_with ) {
      my $sql = "UPDATE borrowers SET ? = ? " . $where_sql;
      $sth = $dbh->prepare( $sql );
      $rows_affected = $sth->execute( $column, $replace_with, $column, $find_value, $list_id );    
    }
    elsif ( $delete ) {
      foreach my $b ( @$borrowers ) {
        ## Code to test for ability to delete
      }
    } 
              
    
}

1;
__END__

=back

=head1 AUTHOR

Kyle M Hall <kyle@kylehall.info>

=cut
