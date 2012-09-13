package C4::Taggable;

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
use base 'Exporter';
use C4::Context;

our @EXPORT_OK   = qw( all_tags add_tag remove_tag remove_tag_from_class has_tag toggle_tag tags tag_frequency search_by_tags );
our %EXPORT_TAGS =   ( mixin => \@EXPORT_OK );

=head1 NAME

C4::Taggable - a mixin that adds tagging-related methods to your class

=head1 SYNOPSIS

Add tagging-related methods to a class:

    package C4::Report;
    use C4::Taggable ':mixin';  # <-- Doing this adds tagging-related methods
                                #     to C4::Report.

Then use the tagging-related methods:

    my @reports = C4::Report->search_by_tags('foo', 'bar');
    for (@reports) {
        $_->add_tag('baz');
        $_->remove_tag('bar');
    }

    for (C4::Report->all_tags) {
        print "$_\n";
    }

=head1 DESCRIPTION

C4::Taggable is a mixin that will add tagging-related methods to your class.
In order for this module to work, the host class has to provide the following
methods:

=over 4

=item new

This should be a constructor that takes an optional hashref as an argument.
The hashref will contain the row data that the object should wrap around.

=item table

This is the name of the table that the host class represents.

For example, L<C4::Report>'s table is C<saved_sql>.

=item primary_key

This is the name of the primary key column for the host class' table.
(Composite keys are not supported at the moment.)

For example, the saved_sql table's primary key is C<id>.

=item foreign_key_for_xtags

This is the name of the field in the many-to-many table which will
be used to refer to rows in the host class' table.

For example, tables that want to refer to saved_sql table should use
C<saved_sql_id> as the foreign key.

=back

In addition to this, the table that stores the many-to-many relations between
tags and the resource represented by the host class should be named

    xtags_and_$table

...where C<$table> is the value returned by C<$class-E<gt>table>.

The scheme for C<xtags_and_$table> should look like:

    CREATE TABLE xtags_and_$table (
        id int(11) NOT NULL auto_increment,
        xtag_id int(11) NOT NULL,
        $foreign_key_for_xtags int(11) NOT NULL,
        UNIQUE (tag_id, $foreign_key_for_xtags),
        PRIMARY KEY (id)
    );

This system also makes use of the xtags table which contains all the tags
ever defined within the C4::Taggable system.  It's schema looks like this:

    CREATE TABLE xtags (
        id int(11) NOT NULL auto_increment,
        name varchar(255) NOT NULL,
        UNIQUE (name),
        PRIMARY KEY (id)
    );

=head1 API

=cut

=head2 add_tag(@tags)

Add tags to an object.  It will return a list of tags that were successfully added.

    $object->add_tag('foo');

This can also be used as a class method to create a tag without associating it with
any specific object.

    C4::Report->add_tag('save-for-later');

=cut

sub _find_xtag {
    my $name = shift;
    my $dbh  = C4::Context->dbh;
    my ($xtag_id) = $dbh->selectrow_array("SELECT id FROM xtags WHERE name = ?", {}, $name);
    return $xtag_id;
}

sub _find_or_create_xtag {
    my $name    = shift;
    my $dbh     = C4::Context->dbh;
    my $xtag_id = _find_xtag($name);
    unless ($xtag_id) {
        $dbh->do("INSERT INTO xtags (name) VALUES (?)", {}, $name);
        $xtag_id = $dbh->last_insert_id(undef, undef, undef, undef);
    }
    return $xtag_id;
}

sub add_tag {
    my ($self, @tags) = @_;
    my $id;
    # kinda sloppy use of $self
    # (also doubling as what should be $class) -- sorry
    if (not ref($self)) {
        $id = 0;
    } else {
        $id = $self->id;
    }
    my $dbh         = C4::Context->dbh;
    my $table       = $self->table;
    my $many_2_many = "xtags_and_$table";
    my $resource    = $self->foreign_key_for_xtags;
    my @added;
    for (@tags) {
        local $dbh->{RaiseError} = 1;
        my $xtag_id = _find_or_create_xtag($_);
        eval {
            $dbh->do("INSERT INTO $many_2_many (xtag_id, $resource) VALUES (?, ?)", {}, $xtag_id, $id);
        };
        unless ($@) {
            push @added, $_;
        }
    }
    return @added;
}

=head2 remove_tag(@tags)

Remove tags from an object.  It will return a list of tags that were successfully removed.

    $object->remove_tag('foo', 'bar');

This can also be used as a class method to remove tags from all instances of a class.

    # This removes 'foo' from all C4::Report objects.
    C4::Report->remove_tag('foo');

=cut

sub remove_tag {
    my ($self, @tags) = @_;
    if (not ref($self)) {
        my $class = $self;
        return $class->remove_tag_from_class(@tags);
    }
    my $dbh         = C4::Context->dbh;
    my $table       = $self->table;
    my $many_2_many = "xtags_and_$table";
    my $resource    = $self->foreign_key_for_xtags;
    my @removed;
    for (@tags) {
        my $xtag_id = _find_xtag($_);
        if ($xtag_id) {
            $dbh->do("DELETE FROM $many_2_many WHERE xtag_id = ? AND $resource = ?", {}, $xtag_id, $self->id);
            push @removed, $_;
        }
    }
    return @removed;
}

sub remove_tag_from_class {
    my ($class, @tags) = @_;
    my $dbh         = C4::Context->dbh;
    my $table       = $class->table;
    my $many_2_many = "xtags_and_$table";
    my @removed;
    for (@tags) {
        my $xtag_id = _find_xtag($_);
        if ($xtag_id) {
            my $count = $dbh->do("DELETE FROM $many_2_many WHERE xtag_id = ?", {}, $xtag_id);
            push @removed, $_ if ($count ne "0E0"); # google for: DBI 0E0
        }
    }
    return @removed;
}

=head2 has_tag

This method will return true if the current object has been tagged with $tag.

    $object->has_tag('foo') && print "foo\n";

This may be used as a class method as well.

    C4::Report->has_tag('foo')  # true if any C4::Report instance is tagged w/ foo

=cut

sub has_tag {
    my ($proto, $tag) = @_;
    return grep { $_ eq $tag } $proto->tags;
}

=head2 toggle_tag(@tags)

Toggle the given tags for the current object.

    $object->toggle_tag('foo');

=cut

sub toggle_tag {
    my ($self, @tags) = @_;
    for (@tags) {
        if ($self->has_tag($_)) {
            $self->remove_tag($_);
        } else {
            $self->add_tag($_);
        }
    }
}

=head2 tags

This method return a list of tags belonging to the object.

    my @tags = $object->tags;

This may also e called as a class method in which case it'll return a list
of all the tags being used by instances of the class.

    # roughly equivalent to C4::Report->all_tags({ unused => 1 })
    my @tags = C4::Report->tags;

=cut

sub tags {
    my ($proto) = @_;
    my $dbh         = C4::Context->dbh;
    my $table       = $proto->table;
    my $many_2_many = "xtags_and_$table";
    my $resource    = $proto->foreign_key_for_xtags;
    my $select      = "SELECT xtags.name FROM xtags JOIN $many_2_many mm ON mm.xtag_id = xtags.id WHERE $resource = ? ORDER BY mm.id";
    #warn $select;
    my $rs = $dbh->selectall_arrayref($select, {}, ((ref $proto) ? $proto->id : 0));
    return map { $_->[0] } @$rs;
}

=head2 all_tags([ \%opts ])

This is a class method that will return a list of all the tags in use by objects
of the mixed in class.

    my @tags = C4::Report->all_tags;

If you want to include unused tags as well:

    my @tags = C4::Report->all_tags({ unused => 1 });

=cut

sub all_tags {
    my ($class, $opts) = @_;
    $opts ||= { unused => 0 };
    my $dbh         = C4::Context->dbh;
    my $table       = $class->table;
    my $many_2_many = "xtags_and_$table";
    my $resource    = $class->foreign_key_for_xtags;
    my $select;
    if ($opts->{unused}) {
        $select = "SELECT DISTINCT xtags.name FROM xtags JOIN $many_2_many mm ON mm.xtag_id = xtags.id ORDER BY xtags.name";
    } else {
        $select = "SELECT DISTINCT xtags.name FROM xtags JOIN $many_2_many mm ON mm.xtag_id = xtags.id WHERE mm.$resource != 0 ORDER BY xtags.name";
    }
    #warn $select;
    my $rs = $dbh->selectall_arrayref($select);
    return map { $_->[0] } @$rs;
}

=head2 tag_frequency

This class method will return a list of hashrefs where each hashref contains a tag
and the number of times the tag is used.

    my @tags = C4::Report->tag_frequency
    for (@tags) {
        print "$_->{tag}: $_->{frequency}\n";
    }

=cut

sub tag_frequency {
    my ($class)     = @_;
    my $dbh         = C4::Context->dbh;
    my $table       = $class->table;
    my $many_2_many = "xtags_and_$table";
    my $resource    = $class->foreign_key_for_xtags;
    my $select      = "SELECT xtags.name, count(xtags.id) as frequency FROM xtags JOIN $many_2_many mm ON mm.xtag_id = xtags.id WHERE mm.$resource != 0 GROUP BY xtags.name ORDER BY xtags.name";

    my @tags = $class->all_tags({ unused => 1 });
    my $rs   = $dbh->selectall_arrayref($select);
    my %used = map { $_->[0] => $_->[1] } @$rs;
    return map {
      if (exists $used{$_}) {
        { tag => $_, frequency => $used{$_} }
      } else {
        { tag => $_, frequency => 0 }
      }
    } @tags;
}

=head2 search_by_tags(@tags, [ \%options ])

This is a class method that lets you search for objects that are tagged
with a given set of tags.  If the final parameter is a hashref, you can
customize the result set as follows:

B<Options>:

=over 4

=item order_by

An optional C<ORDER BY> clause.

=item limit

An optional C<LIMIT> clause.

=item offset

An optional C<OFFSET> clause.

=back

B<Examples>:

    # Search for 1 tag
    my @reports = C4::Report->search_by_tags('foo');

    # Search for 2 tags
    @reports = C4::Report->search_by_tags('foo', 'bar');

    # Search for 3 tags and add \%options at the end
    @reports = C4::Report->search_by_tags('foo', 'bar', 'baz', {
        order_by => 'saved_sql.id DESC',
        limit    => '50',
        offset   => '250'
    });

=cut

sub search_by_tags {
    my ($class, @tags) = @_;
    my $options     = do { if (ref($tags[-1])) { pop @tags } };
    my $dbh         = C4::Context->dbh;
    my $table       = $class->table;
    my $primary_key = $class->primary_key;
    my $foreign_key = $class->foreign_key_for_xtags;
    my @range       = (1 .. scalar(@tags));
    my $last        = $range[-1];
    my $many_2_many = "xtags_and_$table";
    my $cross_joins = join(" CROSS JOIN ", map { "xtags t$_" } @range);
    my $inner_joins = join("\n", (map {
        my $prev = $_ - 1;
        ($_ == 1)
            ? "  INNER JOIN $many_2_many mm$_ ON mm$_.xtag_id = t$_.id"
            : "  INNER JOIN $many_2_many mm$_ ON mm$_.xtag_id = t$_.id AND mm$prev.$foreign_key = mm$_.$foreign_key";
    } @range),"  INNER JOIN $table ON mm$last.$foreign_key = $table.$primary_key");
    my $tags_clause = join(" AND ", map { "t$_.name = ?" } @range);
    my $select      = "SELECT DISTINCT $table.*\nFROM $cross_joins\n$inner_joins\nWHERE $tags_clause AND mm$last.xtag_id != 0\n";
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
    #warn $select;
    my $rs = $dbh->selectall_arrayref($select, { Slice => {} }, @tags);
    return map { $class->new($_, $options) } @$rs;
}

1;

__END__

=head1 SEE ALSO

=over 4

=item L<http://blogs.liblime.com/developers/2009/05/18/implementing-a-mixin-for-tagging/>

This blog post has a brief explanation of the unorthodox technique this module
uses to implement mixins.

=item L<C4::Report>

See L<C4::Report> for an example of how to integrate the L<C4::Taggable> mixin
into a class.

=item tail -f /var/log/mysql/mysql.log

This will help you see the SQL queries as they are being issued.  (If your mysql.log is
somewhere else, adjust the path accordingly.)

=back


=cut
