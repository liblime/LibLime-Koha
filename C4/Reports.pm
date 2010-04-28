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

1;

__END__

=head1 AUTHOR

Jesse Weaver <jesse.weaver@liblime.com>

=cut
