package C4::ReceiptTemplates;

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

use C4::Members;
use C4::Log;
use C4::Debug;
use C4::Dates qw/format_date/;
use Date::Calc qw( Add_Delta_Days );

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    require Exporter;

    # set the version for version checking
    $VERSION = 3.01;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(
      &GetReceiptTemplates
      &GetReceiptTemplate

      &ReceiptTemplateExists

      &SetReceiptTemplate
      &DeleteReceiptTemplate

      &AssignReceiptTemplate
      &GetAssignedReceiptTemplate
      &IsReceiptTemplateAssigned

      &GetTableColumnsFor
      &MuxColumnsForSQL
    );

    use constant DEBUG => 0;
}

sub GetReceiptTemplates {
    my ($params) = @_;
    my $branchcode = $params->{branchcode};
    my $module = $params->{module} || '%';
    my $selected = $params->{selected}
      || '';    ## Optional template code for loops

    return unless ($branchcode);

    my $dbh = C4::Context->dbh;

    my $templates = $dbh->selectall_arrayref(
q{SELECT *, code LIKE ? AS selected FROM receipt_templates WHERE branchcode = ? AND module LIKE ?},
        { Slice => {} }, $selected, $branchcode, $module
    );

    foreach my $t (@$templates) {
        $t->{'assigned'} = IsReceiptTemplateAssigned(
            { code => $t->{'code'}, branchcode => $t->{'branchcode'} } );
    }

    return $templates;
}

sub GetReceiptTemplate {
    my ($params)   = @_;
    my $code       = $params->{code};
    my $branchcode = $params->{branchcode};
    my $action     = $params->{action};

    warn
"GetReceiptTemplate({ code => '$code', branchcode => '$branchcode', action => '$action' })"
      if DEBUG;

    return unless ( ( $code || $action ) && $branchcode );

    $code = GetAssignedReceiptTemplate(
        { action => $action, branchcode => $branchcode } )
      unless ($code);

    my $dbh = C4::Context->dbh;
    return $dbh->selectrow_hashref(
        q{SELECT * FROM receipt_templates WHERE code = ? AND branchcode = ?},
        undef, $code, $branchcode );

}

sub ReceiptTemplateExists {
    my ($params)   = @_;
    my $module     = $params->{module};
    my $code       = $params->{code};
    my $branchcode = $params->{branchcode};

    return unless ( $module && $code && $branchcode );

    my $dbh = C4::Context->dbh;
    my $t   = $dbh->selectall_arrayref(
q{SELECT name FROM receipt_templates WHERE module = ? AND code = ? AND branchcode = ?},
        undef, $module, $code, $branchcode
    );
    return @{$t};
}

sub SetReceiptTemplate {
    my ($params)   = @_;
    my $module     = $params->{module};
    my $code       = $params->{code};
    my $branchcode = $params->{branchcode};
    my $name       = $params->{name};
    my $content    = $params->{content};

    return unless ( $module && $code && $branchcode && $name && $content );

    my $dbh = C4::Context->dbh;
    return $dbh->do(
q{REPLACE INTO receipt_templates ( module, code, branchcode, name, content) VALUES (?,?,?,?,?)},
        undef, $module, $code, $branchcode, $name, $content
    );
}

sub DeleteReceiptTemplate {
    my ($params)   = @_;
    my $module     = $params->{module};
    my $code       = $params->{code};
    my $branchcode = $params->{branchcode};

    my $dbh = C4::Context->dbh;
    $dbh->do(
q{DELETE FROM receipt_templates WHERE module = ? AND code = ? AND branchcode = ?},
        undef, $module, $code, $branchcode
    );
}

sub AssignReceiptTemplate {
    my ($params)   = @_;
    my $action     = $params->{action};
    my $branchcode = $params->{branchcode};
    my $code       = $params->{code};

    return unless ( $action && $branchcode );

    my $dbh = C4::Context->dbh;
    return $dbh->do(
q{REPLACE INTO receipt_template_assignments ( action, branchcode, code) VALUES (?,?,?)},
        undef, $action, $branchcode, $code
    );
}

sub GetAssignedReceiptTemplate {
    my ($params)   = @_;
    my $action     = $params->{action};
    my $branchcode = $params->{branchcode};

    return unless ( $action && $branchcode );

    my $dbh = C4::Context->dbh;
    my $r   = $dbh->selectrow_hashref(
q{SELECT receipt_template_assignments.code FROM receipt_template_assignments WHERE action = ? AND branchcode = ?},
        undef, $action, $branchcode
    );

    return ( defined $r ) ? $r->{code} : '';
}

sub IsReceiptTemplateAssigned {
    my ($params)   = @_;
    my $code       = $params->{code};
    my $branchcode = $params->{branchcode};

    return unless ( $code && $branchcode );

    my $dbh = C4::Context->dbh;
    my $r   = $dbh->selectrow_hashref(
q{SELECT COUNT(*) AS count FROM receipt_template_assignments WHERE code = ? AND branchcode = ?},
        undef, $code, $branchcode
    );

    return $r->{count};
}

sub GetTableColumnsFor {
    my @tables = @_;

    my @columns;

    foreach my $table (@tables) {

        my $name;
        if ( ref($table) eq "HASH" ) {
            $name  = $table->{'name'};
            $table = $table->{'table'};
        }

        my $sql          = "SHOW COLUMNS FROM $table";
        my $table_prefix = $table . q|.|;
        $table_prefix = $name . q|.| if ($name);

        my $rows =
          C4::Context->dbh->selectall_arrayref( $sql, { Slice => {} } );

        for my $row ( @{$rows} ) {
            push( @columns, $table_prefix . $row->{Field} );
        }
    }

    return @columns;
}

sub MuxColumnsForSQL {
    my @columns = @_;

    my @c;
    foreach my $c (@columns) {
        push( @c, "$c AS '$c'" );
    }
    my $columns = join( ',', @c );

    return ($columns);
}

1;
__END__
