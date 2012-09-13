package C4::Report;

# Copyright 2009 Katipo Communications
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
use C4::Taggable ':mixin';
use C4::Dates 'format_date';
use C4::Members;

=head1 NAME

C4::Report - an object representing a row in the C<saved_sql> table

=head1 SYNOPSIS

Using a report:

    use C4::Report;
    my $report = C4::Report->find(1);
    print $report->name, "\n";
    print $report->savedsql, "\n";
    $report->notes('run this daily');
    $report->add_tag('daily');
    $report->update;

Find all reports tagged with 'daily' and 'circulation':

    my @reports = C4::Report->search_by_tags('daily', 'circulation');

=head1 DESCRIPTION

This module provides an OO interface to SQL reports.  It also mixes in
L<C4::Taggable> to add tagging functionality.

=head1 API

=head2 new(\%attr)

This method constructs a C4::Report object in memory.

=cut

sub new {
    my ($class, $attr, $_options) = @_;
    $_options ||= {};
    $attr     ||= {};
    my $options = { format_date => 1, tags => 1, borrower => 1, %$_options };
    my $self = bless { %$attr } => $class;
    $self->reformat_date if ($options->{format_date});
    $self->load_tags     if ($options->{tags});
    $self->load_borrower if ($options->{borrower});
    return $self
}

=head2 table

"saved_sql"

=head2 resource_id_field

"saved_sql_id"

=head2 primary_key

"id"

=cut

sub table                 { "saved_sql"    }
sub primary_key           { "id"           }
sub foreign_key_for_xtags { "saved_sql_id" }

=head2 find($id)

This method will construct a C4::Report object using data from the saved_sql table.

    C4::Report->find(1)

=cut

sub find {
    my ($class, $id) = @_;
    my $dbh    = C4::Context->dbh;
    my $sql    = "SELECT * FROM saved_sql WHERE id = ?";
    my $rs     = $dbh->selectall_arrayref($sql, { Slice => {} }, $id);
    my $report = $rs->[0];
    my $object = $class->new($report);
    return $object;
}

=head2 id

=head2 borrowernumber

=head2 date_created

=head2 last_modified

=head2 savedsql

=head2 last_run

=head2 report_name

=head2 type

=head2 notes

All of the above represent columns in the saved_sql table.

=cut

# attributes that directly map to what's in the saved_sql table
my @attributes = qw(
    borrowernumber
    date_created
    last_modified
    savedsql
    last_run
    report_name
    type
    notes
);

=head2 borrower

This is a hashref representing the koha user that created this report.

=head2 borrowersurname

Report creator's surname.

=head2 borrowerfirstname

Report creator's first name.

=head2 last_modified_f

This is $self->last_modified with format_date() applied to it.

=head2 date_created_f

This is $self->date_created with format_date() applied to it.

=cut

# aside from id, attributes that are just in memory for convenience
my @extra = qw(
    id
    borrower
    borrowersurname
    borrowerfirstname
    date_created_f
    last_modified_f
);

sub _accessor {
    my $attr = shift;
    sub {
        my ($self, $value) = @_;
        if ($value) {
            $self->{$attr} = $value;
        } else {
            $self->{$attr};
        }
    }
}

{
    no strict 'refs';
    no warnings 'once';
    *{$_} = _accessor($_) for (@attributes, @extra);
}

my $attributes_sql = join(', ' => map { "$_ = ?" } @attributes);
sub attributes_sql { $attributes_sql }

=head2 update

This method updates the database with the current state of the C4::Report object.

    $report->update;

=cut

sub update {
    my ($self) = @_;
    my @x      = localtime;
    my $now    = sprintf('%d-%02d-%02d %02d:%02d:%02d', $x[5]+1900, $x[4]+1, $x[3], $x[2], $x[1], $x[0]);
    my $dbh    = C4::Context->dbh;
    my $sql    = "UPDATE saved_sql SET $attributes_sql WHERE id = ?";
    $self->last_modified($now);
    $dbh->do($sql, undef, (map { $self->$_ } @attributes), $self->id);
}

=head2 delete

When called as an instance method, the current object will be deleted.

    $report->delete;

When called as a class method, you can provide the id of a report to delete.

    C4::Report->delete(5);

=cut

sub delete {
    my ($proto, $id) = @_;
    if ($id) {
        return _delete_by_id($id);
    } else {
        if (ref $proto) {
            my $self = $proto;
            return _delete_by_id($self->id);
        } else {
            warn "When delete is called as a class method, an id needs to be provided.";
            return undef;
        }
    }
}

sub _delete_by_id {
    my $id = shift;
    my $dbh = C4::Context->dbh;
    $dbh->do("DELETE FROM saved_sql WHERE id = ?", {}, $id);
}

sub reformat_date {
    my ($self) = @_;
    $self->date_created_f(format_date($self->date_created));
    $self->last_modified_f(format_date($self->last_modified));
}


sub load_tags {
    my ($self) = @_;
    $self->{tags} = [ map { { name => $_ } } $self->tags ];
}

sub load_borrower {
    my ($self) = @_;
    if ($self->borrowernumber) {
        $self->borrower(GetMember($self->borrowernumber, 'borrowernumber'));
        if ($self->borrower) {
            $self->borrowerfirstname($self->borrower->{firstname});
            $self->borrowersurname($self->borrower->{surname});
        }
    }
}

sub all {
    my ($class, $_options) = @_;
    $_options ||= {};
    my $options = { order_by => 'id', format_date => 1, tags => 1, borrower => 1, %$_options };
    my $dbh     = C4::Context->dbh;
    my $select  = "SELECT * FROM saved_sql ";
    if ($options) {
        if (exists $options->{order_by}) {
            $select .= "ORDER BY $options->{order_by}\n";
        }
        if (exists $options->{limit}) {
            $select .= "LIMIT $options->{limit}\n";
        }
        if (exists $options->{offset}) {
            $select .= "OFFSET $options->{offset}\n";
        }
    }
    my $rs = $dbh->selectall_arrayref($select, { Slice => {} });
    return map {
        $class->new($_, $options);
    } @$rs;
}

1;

__END__

=head1 SEE ALSO

L<C4::Taggable>, L<C4::Reports>, L<C4::Reports::Guided>

=cut
