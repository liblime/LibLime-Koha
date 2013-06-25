#!/usr/bin/env perl

# written 27/01/2000
# script to display borrowers reading record

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

use C4::Auth;
use C4::Output;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Reserves;
use C4::Biblio;
use C4::Koha;

use C4::Dates qw/format_date/;
my $input=new CGI;

my $borrowernumber=$input->param('borrowernumber');

my ($template, $loggedinuser, $cookie) = get_template_and_user({template_name => "members/holdhistory.tmpl",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired => {borrowers => '*'},
				debug => 1,
				});

#get borrower details
my $data=GetMember($borrowernumber,'borrowernumber');
if (   $data
    && C4::Branch::CategoryTypeIsUsed('patrons')
    && C4::Members::ConstrainPatronSearch())
{
    my $agent = C4::Members::GetMember($loggedinuser);
    $data = undef
        unless C4::Branch::BranchesAreSiblings(
            $data->{branchcode}, $agent->{branchcode}, 'patrons');
}
unless (defined $data) {
    output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

$template->param( 
   borrowernumber => $data->{'borrowernumber'},
   firstname      => $data->{'firstname'},
   surname        => $data->{'surname'},
   cardnumber     => $data->{'cardnumber'},
   categorycode   => $data->{'categorycode'},
   categoryname   => $data->{'description'},
   address        => $data->{'address'},
   address2       => $data->{'address2'},
   city           => $data->{'city'},
   zipcode        => $data->{'zipcode'},
   phone          => $data->{'phone'},
   email          => $data->{'email'},
   branchcode     => $data->{'branchcode'},
   branchname     => GetBranchName($data->{'branchcode'}),
   UseReceiptTemplates => C4::Context->preference("UseReceiptTemplates"),
);


my @borroweroldreserv;
# show the borrower's old filled reservations on Filled Holds tab
@borroweroldreserv = GetOldReservesFromBorrowernumber($borrowernumber,'fill','intranet');
my @filledreservloop;
foreach my $num_res (@borroweroldreserv) {
  my %getreserv;
  my $getiteminfo  = GetBiblioFromItemNumber( $num_res->{'itemnumber'} );
  my $itemtypeinfo = getitemtypeinfo( $getiteminfo->{'itemtype'} );

  $getreserv{reservenumber} = $num_res->{'reservenumber'};
  $getreserv{biblionumber} = $num_res->{'biblionumber'};
  $getreserv{borrowernumber} = $num_res->{'borrowernumber'};
  $getreserv{reservedate} = format_date($num_res->{'reservedate'});
  $getreserv{holdexpdate} = format_date($num_res->{'expirationdate'});
  my ($filldate,$filltime) = split(/\s+/, $num_res->{'timestamp'});
  $getreserv{filldate} = format_date($filldate);
  foreach (qw(barcode author itemcallnumber )) {
    $getreserv{$_} = $getiteminfo->{$_};
  }
  my $biblioData = GetBiblioData($num_res->{'biblionumber'});
  $getreserv{title} = $biblioData->{'title'};
  $getreserv{itemtype} = $itemtypeinfo->{'description'};
  push( @filledreservloop, \%getreserv );
}

# return result to the template
$template->param( filledreservloop => \@filledreservloop,
  filledreserves_count => scalar @filledreservloop,
);

# show the borrower's old expired reservations on Expired Holds tab
@borroweroldreserv = GetOldReservesFromBorrowernumber($borrowernumber,'expiration','intranet');
my @expiredreservloop;
foreach my $num_res (@borroweroldreserv) {
  my %getreserv;
  $getreserv{biblionumber} = $num_res->{'biblionumber'};
  # The itemnumber is not necessarily defined for expired holds.
  if (defined ($num_res->{'itemnumber'})) {
    my $getiteminfo  = GetBiblioFromItemNumber( $num_res->{'itemnumber'} );
    my $itemtypeinfo = getitemtypeinfo( $getiteminfo->{'itemtype'} );
    foreach (qw(title author itemcallnumber)) {
      $getreserv{$_} = $getiteminfo->{$_};
    }
    $getreserv{itemtype}  = $itemtypeinfo->{'description'};
    $getreserv{barcodereserv} = $getiteminfo->{'barcode'};
  }
  else {
    my ($bibliocnt, @biblio) = GetBiblio($num_res->{'biblionumber'});
    foreach (qw(title author)) {
      $getreserv{$_} = $biblio[0]->{$_};
    }
  }
  $getreserv{reservedate} = C4::Dates->new($num_res->{'reservedate'},'iso')->output('syspref');
  $getreserv{holdexpdate} = format_date($num_res->{'expirationdate'});
  $getreserv{waitingposition} = $num_res->{'priority'};
  $getreserv{reservenumber} = $num_res->{'reservenumber'};
  push( @expiredreservloop, \%getreserv );
}

# return result to the template
$template->param( expiredreservloop => \@expiredreservloop,
  countexpiredreserv => scalar @expiredreservloop,
);

# show the borrower's old cancelled reservations on Cancelled Holds tab
my $dbh = C4::Context->dbh;
@borroweroldreserv = ();
@borroweroldreserv = GetOldReservesFromBorrowernumber($borrowernumber,'cancellation','intranet');
my @cancelledreservloop;
my ($sth,$modresnumber);
foreach my $num_res (@borroweroldreserv) {
  my %getreserv;
  my (@bind,$query);
  $query = "SELECT usercode FROM statistics WHERE type='reserve_canceled' AND other = ? AND borrowernumber = ? AND datetime LIKE ? ";
  push(@bind,"$num_res->{'biblionumber'}","$borrowernumber","$num_res->{'cancellationdate'}%");
  $sth = $dbh->prepare($query);
  $sth->execute(@bind);
  $modresnumber = $sth->fetchrow;
  if (defined($modresnumber)) {
    $getreserv{linkcancellationdate} = 1;
    $getreserv{modresnumber} = $modresnumber;
    my $modresborrower = GetMember($modresnumber);
    $getreserv{modresfirstname} = $modresborrower->{'firstname'};
    $getreserv{modressurname} = $modresborrower->{'surname'};
  }
  # Determine if itemnumber is available.  If so, then fetch iteminfo
  # like above.
  if (defined ($num_res->{'itemnumber'})) {
    my $getiteminfo = GetBiblioFromItemNumber( $num_res->{'itemnumber'} );
    my $itemtypeinfo = getitemtypeinfo( $getiteminfo->{'itemtype'} );
    $getreserv{barcodereserv} = $getiteminfo->{'barcode'};
    $getreserv{itemtype} = $itemtypeinfo->{'description'};
    $getreserv{itemcallnumber} = $getiteminfo->{'itemcallnumber'};
  }
  my ($bibliocnt, @biblio) = GetBiblio( $num_res->{'biblionumber'} );
  $getreserv{reservedate} = C4::Dates->new($num_res->{'reservedate'},'iso')->output('syspref');
  $getreserv{cancellationdate} = format_date($num_res->{'cancellationdate'});
  foreach (qw(biblionumber title author )) {
    $getreserv{$_} = $biblio[0]->{$_};
  }
  $getreserv{waitingposition} = $num_res->{'priority'};
  $getreserv{reservenumber} = $num_res->{'reservenumber'};
  push( @cancelledreservloop, \%getreserv );
}

# return result to the template
$template->param( cancelledreservloop => \@cancelledreservloop,
  countcancelledreserv => scalar @cancelledreservloop,
);

$template->param( holdhistoryview => 1 );

output_html_with_http_headers $input, $cookie, $template->output;
