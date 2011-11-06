#!/usr/bin/env perl

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

=head1 admin/itemstatus.pl

script to administer the itemstatus table

 This software is placed under the gnu General Public License, v2 (http://www.gnu.org/licenses/gpl.html)

 ALSO :
 this script uses an $op to know what to do.
 if $op is empty or none of the following values,
	- the default screen is build (with all records, or filtered data).
	- the user can click on new item status, edit or delete record.
 if $op=add_form
	- if primkey exists, this is a modification, so we read the $primkey record
	- builds the add/modify form
 if $op=add_validate
	- the user has just sent data, so we create/modify the record
 if $op=delete_form
	- we show the record having primkey=$primkey and ask for deletion validation form
 if $op=delete_confirm
	- we delete the record having primkey=$primkey

=cut

use strict;
use CGI;

use List::Util qw/min/;
use File::Spec;

use C4::Koha;
use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;

### Not sure function below is needed
sub StringSearch {
    my ( $searchstring, $type ) = @_;
    my $dbh = C4::Context->dbh;
    $searchstring =~ s/\'/\\\'/g;
    my @data = split( ' ', $searchstring );
    my $sth = $dbh->prepare(
        "SELECT * FROM itemstatus WHERE (description LIKE ?) ORDER BY statuscode"
	);
    $sth->execute("$data[0]%");
    return $sth->fetchall_arrayref({});		# return ref-to-array of ref-to-hashes
								# like [ fetchrow_hashref(), fetchrow_hashref() ... ]
}

my $input       = new CGI;
my $searchfield = $input->param('description');
my $script_name = "/cgi-bin/koha/admin/itemstatus.pl";
my $statuscode  = $input->param('statuscode');
my $pagesize    = 10;
my $op          = $input->param('op');
$searchfield =~ s/\,//g;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "admin/itemstatus.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 1 },
        debug           => 1,
    }
);

$template->param(script_name => $script_name);
if ($op) {
	$template->param($op  => 1); # we show only the TMPL_VAR names $op
} else {
    $template->param(else => 1);
}

my $dbh = C4::Context->dbh;

################## ADD_FORM ##################################
# called by default. Used to create form to add or modify a record
if ( $op eq 'add_form' ) {
    #---- if primkey exists, it's a modify action, so read values to modify...
    my $data;
    if ($statuscode) {
        my $sth = $dbh->prepare("select * from itemstatus where statuscode=?");
        $sth->execute($statuscode);
        $data = $sth->fetchrow_hashref;
    }

    $template->param(
        statuscode      => $statuscode,
        description     => $data->{'description'},
        holdsallowed    => $data->{'holdsallowed'},
        holdsfilled     => $data->{'holdsfilled'},
        template        => C4::Context->preference('template'),
    );

    # END $OP eq ADD_FORM
################## ADD_VALIDATE ##################################
    # called by add_form, used to insert/modify data in DB
}
elsif ( $op eq 'add_validate' ) {
    my $query = "
        SELECT statuscode
        FROM   itemstatus
        WHERE  statuscode = ?
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute($statuscode);
    if ( $sth->fetchrow ) {		# it's a modification
        my $query2 = '
            UPDATE itemstatus
            SET    description = ?
                 , holdsallowed = ?
                 , holdsfilled  = ?
            WHERE statuscode = ?
        ';
        $sth = $dbh->prepare($query2);
        $sth->execute(
            $input->param('description'),
            $input->param('holdsallowed') ? 1 : 0,
            $input->param('holdsfilled')  ? 1 : 0,
            $input->param('statuscode')
        );
    }
    else {    # add a new itemtype & not modif an old
        my $query = "
            INSERT INTO itemstatus
                (statuscode,description,holdsallowed,holdsfilled)
            VALUES
                (?,?,?,?);
            ";
        my $sth = $dbh->prepare($query);
        $sth->execute(
            $input->param('statuscode'),
            $input->param('description'),
            $input->param('holdsallowed') ? 1 : 0,
            $input->param('holdsfilled')  ? 1 : 0,
        );
    }

    print $input->redirect('itemstatus.pl');
    exit;

    # END $OP eq ADD_VALIDATE
################## DELETE_CONFIRM ##################################
    # called by default form, used to confirm deletion of data in DB
}
elsif ( $op eq 'delete_confirm' ) {

    my $sth =
      $dbh->prepare("select * from itemstatus where statuscode =?");
    $sth->execute($statuscode);
    my $data = $sth->fetchrow_hashref;
    $template->param(
        statuscode      => $statuscode,
        description     => $data->{description},
        holdsallowed    => $data->{holdsallowed},
        holdsfilled     => $data->{holdsfilled},
    );

    # END $OP eq DELETE_CONFIRM
################## DELETE_CONFIRMED ##################################
  # called by delete_confirm, used to effectively confirm deletion of data in DB
}
elsif ( $op eq 'delete_confirmed' ) {
    my $itemstatus = $input->param('statuscode');
    my $sth        = $dbh->prepare("delete from itemstatus where statuscode=?");
    $sth->execute($statuscode);
## Add more code here to change otherstatus field in items table;
    print $input->redirect('itemstatus.pl');
    exit;
    # END $OP eq DELETE_CONFIRMED
################## DEFAULT ##################################
}
else {    # DEFAULT
    my ($results) = StringSearch( $searchfield, 'web' );
    my $page = $input->param('page') || 1;
    my $first = ( $page - 1 ) * $pagesize;

    # if we are on the last page, the number of the last word to display
    # must not exceed the length of the results array
    my $last = min( $first + $pagesize - 1, scalar @{$results} - 1, );
    my @loop;
    foreach my $itemstatus ( @{$results}[ $first .. $last ] ) {
        push( @loop, $itemstatus);
    }

    $template->param(
        loop           => \@loop,
        pagination_bar => pagination_bar(
            $script_name, getnbpages( scalar @{$results}, $pagesize ),
            $page,        'page'
        )
    );
}    #---- END $OP eq DEFAULT

output_html_with_http_headers $input, $cookie, $template->output;
