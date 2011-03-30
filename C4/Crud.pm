package C4::Crud;

# Copyright 2008 LibLime, Inc.
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

use C4::Context;
use C4::Koha;
use C4::Debug;

use vars qw( $debug );

=head1 NAME

Crud - Koha baseclass for Create, Read, Update, and Delete operations

=head1 SYNOPSIS

package C4::Person;
use base qw( C4::Crud );
sub _tablename {
    return 'person';
}
sub _primary_key_field {
    return 'person_id';
}
sub _fields {
    return ( 
            'person_id',
            'name',
            'birthdate',
        );
}

Then, elsewhere in code,

  my $person = C4::Person->new( { person_id => $person_id } );


=head1 DESCRIPTION

This class is meant to be a baseclass for Koha classes that represent
a database table.

=cut


sub new {
    my $class = shift;
    my $args  = shift;
    my $self  = {};
    bless( $self, $class );
    if ( exists $args->{ $self->_primary_key_field() } ) {
        $self->_init( { $self->_primary_key_field() => $args->{ $self->_primary_key_field() } } );
    }
    return $self;
}

sub insert {
    my $self = shift;

    # if this one already exists, just update it. Don't insert.
    if ( $self->{ $self->_primary_key_field() } ) {
        return $self->update();
    }

    my @fields_to_insert = $self->_fields();
    # my @fields_to_insert = grep { exists $self->{$_} } $self->_fields();

    my $sql = sprintf( 'INSERT INTO %s ( %s ) VALUES ( %s )',
                       $self->_tablename(),
                       join(', ', @fields_to_insert ),
                       join(', ', map {'?'} @fields_to_insert ),
                  );
    
    warn $sql if $self->_debug();
    warn $self->_dump if $self->_debug();
    my $sth = $self->_dbh->prepare( $sql );
    my $result = $sth->execute( map { $self->{$_} } @fields_to_insert );
    $self->{ $self->_primary_key_field() } = $self->_dbh->{'mysql_insertid'};
    $self->_init();
    return $self->{ $self->_primary_key_field() };
}

sub delete {
    my $self = shift;

    my $sql = sprintf( 'DELETE FROM %s WHERE %s = ?',
                       $self->_tablename(),
                       $self->_primary_key_field(),
                  );
    
    warn $sql if $self->_debug();
    warn $self->_dump if $self->_debug();
    my $sth = $self->_dbh->prepare( $sql );
    my $result = $sth->execute( $self->{ $self->_primary_key_field() } );
    return $result;
}

sub update {
    my $self = shift;

    my $sql = sprintf(
        'UPDATE %s SET %s WHERE %s = ?',
        $self->_tablename(),
        join( ', ', map { "$_ = ?" } $self->_updatable_fields() ),
        $self->_primary_key_field(),
    );

    warn $sql if $self->_debug();
    warn $self->_dump if $self->_debug();
    my $sth = $self->_dbh->prepare($sql);
    my $result = $sth->execute( map { $self->{$_} } $self->_updatable_fields, $self->_primary_key_field() );
    $self->_init();
    return $self->{ $self->_primary_key_field() };
}

sub _init {
    my $self = shift;
    my $args = shift;

    # If they didn't pass in a _primary_key_field, check if we have one already.
    $args->{$self->_primary_key_field} = $self->{$self->_primary_key_field} unless exists $args->{$self->_primary_key_field};

    # if we still don't have a $self->_primary_key_field, bail out.
    return unless ( defined $args->{$self->_primary_key_field} );
    
    my $sql = sprintf( 'SELECT %s FROM %s WHERE %s = ?',
                       join( ', ', $self->_fields() ),
                       $self->_tablename(),
                       $self->_primary_key_field() );
    warn $sql if $self->_debug();
    my $sth = $self->_dbh->prepare( $sql );
    my $executed = $sth->execute( $args->{$self->_primary_key_field} );
    my $result = $sth->fetchrow_hashref();
    $sth->finish();

    # populate our fields.
    foreach my $field ( $self->_fields() ) {
        $self->{$field} = $result->{$field};
    }
    return;
}

sub _dbh {
    return C4::Context->dbh;
}

sub _dump {
    my $self = shift;

    my %fields = map { $_ => $self->{$_} } $self->_fields;
    return Data::Dumper->Dump( [ \%fields ], [ 'fields' ] );
}

sub _debug {
    
    return 0;
    # return $debug;
}

=head3 _updatable_fields

returns list of fields that are NOT the primary_key_field. These are
fields that you can update.

=cut

sub _updatable_fields {
    my $self = shift;
    return grep { $_ ne $self->_primary_key_field() } $self->_fields();
}

1;
