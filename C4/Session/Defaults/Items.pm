package C4::Session::Defaults::Items;

# Copyright (C) 2010 Kyle Hall <kyle@kylehall.info>
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

use C4::Auth;
use Koha;
use C4::Context;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {   
    $VERSION = 1.00;

        require Exporter;
    @ISA = qw( Exporter );
 
    # function exports
    @EXPORT = qw(
        &get
        &set
        &save
        &load
        &clear
        &delete

        &name
        
        &isUsingDefaults        
        
        &getSavedDefaultsList
    );
}

our $debug = 1;

=head1 NAME

C4::Session::Defaults::Items

=head1 SYNOPSIS

use C4::Session::Defaults::Items;

=head1 DESCRIPTION

This is a class for managing defaults to be
used when adding new items to a record.

It is meant to set, store, and retrieve defaults
for the current session.

=cut

sub new {
    my $class = shift;

    my $input = new CGI;
    my $sessionID = $input->cookie("CGISESSID");
    my $session = C4::Auth::get_session($sessionID);

    my $self = {
         _session => $session,
         _prefix => 'session_default_',	## Prefix for standard defaults
         _cprefix => 'using_',		## Pre-prefix for configurations that should not be stored in the db.
    };

    bless $self, $class;
    return $self;
}

sub get {
    my ( $self, %params ) = @_;
    my $field = $params{'field'};
    my $subfield = $params{'subfield'};
    
    return unless ( $field );
    
    my $param = $self->{'_prefix'} . $field;
    $param .= "_$subfield" if ( $subfield );    
    
    return $self->{'_session'}->param( $param );    
}

sub set {
    my ( $self, %params ) = @_;
    my $field = $params{'field'};
    my $subfield = $params{'subfield'};
    my $value = $params{'value'};
    
    return unless ( $field && $value );
    
    my $param = $self->{'_prefix'} . $field;
    $param .= "_$subfield" if ( $subfield );
    
    $self->{'_session'}->param($param, $value);
    
    $self->_setUsingDefaults();
    
    $self->_flush();
}

sub save {
    my ( $self, %params ) = @_;
    my $name = $params{'name'};
    
    warn "C4::Session::Defaults::Items->save( name => '$name' )" if $debug;

    my $branchcode = C4::Context->userenv->{'branch'};
    
    my $dbh = C4::Context->dbh;
    my $sql = "INSERT INTO session_defaults ( `branchcode`, `name`, `key`, `value` ) VALUES ( ?, ?, ?, ? )";
    my $sth = $dbh->prepare( $sql );

    my $params = $self->{'_session'}->dataref();

    Data::Dumper::Dumper( $params );

    while ( my ($key, $value) = each %$params ) {
        $sth->execute( $branchcode, $name, $key, $value ) if ( $key =~ m/^$self->{'_prefix'}/ );
    }    

    $self->_setUsingDefaultsName( name => $name );

    $self->_flush();
}

sub load {
    my ( $self, %params ) = @_;
    my $name = $params{'name'};

    warn "C4::Session::Defaults::Items->load( name => '$name' )" if $debug;

    return unless ( $name );

    $self->clear();

    my $branchcode = C4::Context->userenv->{'branch'};
    
    my $dbh = C4::Context->dbh;
    my $sql = "SELECT * FROM session_defaults WHERE branchcode = ? AND name = ?";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $branchcode, $name );

    while ( my $r = $sth->fetchrow_hashref() ) {
        $self->{'_session'}->param( $r->{'key'}, $r->{'value'} );
    }

    $self->_setUsingDefaultsName( name => $name );

    
    $self->_flush();
}

sub clear {
    my ( $self, %params ) = @_;
    
    my $params = $self->{'_session'}->dataref();

    while ( my ($key, $value) = each %$params ) {
        $self->{'_session'}->clear( $key ) if ( $key =~ m/^$self->{'_prefix'}/);
    }    

    $self->_clearUsingDefaults();

    $self->_flush();
}

sub delete {
    my ( $self, %params ) = @_;

    my $branchcode = C4::Context->userenv->{'branch'};    
    my $name = $self->name();

    warn "C4::Session::Defaults::Items->delete( name = '$name', branchcode = '$branchcode' )" if $debug;

    my $dbh = C4::Context->dbh;
    my $sql = "DELETE FROM session_defaults WHERE branchcode = ? AND name = ?";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $branchcode, $name );

    $self->clear();
}

sub name {
    my ( $self, %params ) = @_;

    return $self->{'_session'}->param( $self->{'_cprefix'} . $self->{'_prefix'} . 'name' );
}

sub getSavedDefaultsList {
    my ( $self, %params ) = @_;
    my $branchcode = $params{'branchcode'};
    my $getAll = $params{'getAll'};

    #warn "getSavedDefaultsList( branchcode => '$branchcode', getAll => '$getAll' )" if $debug;

    my $branchcode = $branchcode || C4::Context->userenv->{'branch'};
    $branchcode = '%' if ( $getAll );

    my $flags = C4::Auth::haspermission( C4::Context->userenv->{'id'} );
    $branchcode = '%' if ( $flags->{'superlibrarian'} && !$params{'branchcode'} );
    
    my $dbh = C4::Context->dbh;
    my $sql = "SELECT DISTINCT( name ) FROM session_defaults WHERE branchcode LIKE ? ORDER BY name";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $branchcode );

    my $name = $self->name();
    my @results;
    while ( my $r = $sth->fetchrow_hashref() ) {
        $r->{'selected'} = 1 if ( $r->{'name'} eq $name );
        push( @results, $r );
    }
    
    return \@results;
}

sub isUsingDefaults {
    my ( $self, %params ) = @_;

    return $self->{'_session'}->param( $self->{'_cprefix'} . $self->{'_prefix'} );
}

sub _setUsingDefaults {
    my ( $self, %params ) = @_;

    $self->{'_session'}->param( $self->{'_cprefix'} . $self->{'_prefix'}, 1 );
}

sub _clearUsingDefaults {
    my ( $self, %params ) = @_;

    $self->_clearUsingDefaultsName();
    $self->{'_session'}->clear( $self->{'_cprefix'} . $self->{'_prefix'} );
}

sub _setUsingDefaultsName {
    my ( $self, %params ) = @_;
    my $name = $params{'name'};

    $self->{'_session'}->param( $self->{'_cprefix'} . $self->{'_prefix'} . 'name', $name );
    
    $self->_setUsingDefaults();
}

sub _clearUsingDefaultsName {
    my ( $self, %params ) = @_;

    $self->{'_session'}->clear( $self->{'_cprefix'} . $self->{'_prefix'} . 'name' );
}

sub _flush {
    my ( $self, %params ) = @_;

    $self->{'_session'}->flush();
}

sub _dumpCurrentParams {
    my ( $self, %params ) = @_;

    my $params = $self->{'_session'}->dataref();

    warn "CURRENT ITEM DEFAULT VALUES SESSION PARAMETERS";

    while ( my ($key, $value) = each %$params ) {
        warn "'$key' => '$value'" if ( $key =~ m/^$self->{'_prefix'}/ || $key =~ m/^$self->{'_cprefix'}$self->{'_prefix'}/ );
    }    
}

1;
