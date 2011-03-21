#!/usr/bin/env perl

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

use C4::Auth;
use C4::Koha;
use C4::Circulation;
use C4::Dates qw/format_date/;
use C4::Members;
use C4::Reserves;
use C4::Biblio;

use C4::Output;

my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-holdhistory.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

# get borrower information ....
my $borr = GetMemberDetails( $borrowernumber );
$template->param( firstname => $borr->{'firstname'} );
$template->param( surname => $borr->{'surname'} );

# Get the filled reserve items...
my @filledreserves  = GetOldReservesFromBorrowernumber( $borrowernumber,'fill','opac' );
my @filledreservesloop;
foreach my $res (@filledreserves) {
    my %filledreserve;
    $filledreserve{reservenumber} = $res->{'reservenumber'};
    $filledreserve{biblionumber} = $res->{'biblionumber'};
    $filledreserve{borrowernumber} = $res->{'borrowernumber'};
    $filledreserve{reservedate} = format_date( $res->{'reservedate'} );
    $filledreserve{holdexpdate} = format_date( $res->{'expirationdate'} );
    my ($filldate,$filltime) = split(/\s+/, $res->{'timestamp'});
    $filledreserve{filldate} = format_date( $filldate );
    my $biblioData = GetBiblioData($res->{'biblionumber'});
    $filledreserve{reserves_title} = $biblioData->{'title'};
    _get_additional_item_info(\%filledreserve,$biblioData);
    push( @filledreservesloop, \%filledreserve );
}
$template->param( FILLEDRESERVES => \@filledreservesloop );
$template->param( filledreserves_count => scalar @filledreservesloop );

# Get the expired reserve items...
my @expiredreserves  = GetOldReservesFromBorrowernumber( $borrowernumber,'expiration','opac' );
my @expiredreservesloop;
foreach my $res (@expiredreserves) {
    next if (!$res->{'displayexpired'});
    my %expiredreserve;
    $expiredreserve{reservenumber} = $res->{'reservenumber'};
    $expiredreserve{biblionumber} = $res->{'biblionumber'};
    $expiredreserve{borrowernumber} = $res->{'borrowernumber'};
    $expiredreserve{reservedate} = format_date( $res->{'reservedate'} );
    $expiredreserve{holdexpdate} = format_date( $res->{'expirationdate'} );
    my $biblioData = GetBiblioData($res->{'biblionumber'});
    $expiredreserve{reserves_title} = $biblioData->{'title'};
    _get_additional_item_info(\%expiredreserve,$biblioData);
    push( @expiredreservesloop, \%expiredreserve );
}
$template->param( EXPIREDRESERVES => \@expiredreservesloop );
$template->param( expiredreserves_count => scalar @expiredreservesloop );

# Get the cancelled reserved items...
my $dbh = C4::Context->dbh;
my @cancelledreserves  = GetOldReservesFromBorrowernumber( $borrowernumber,'cancellation','opac' );
my @cancelledreservesloop;
foreach my $res (@cancelledreserves) {
    my %cancelledreserve;
    my (@bind,$query);
    $query = "SELECT usercode FROM statistics WHERE type='reserve_canceled' AND other = ? AND borrowernumber = ? AND datetime LIKE ? ";
    push(@bind,"$res->{'biblionumber'}","$borrowernumber","$res->{'cancellationdate'}%");
    my $sth = $dbh->prepare($query);
    $sth->execute(@bind);
    my $modresnumber = $sth->fetchrow;
    if (defined($modresnumber)) {
      $cancelledreserve{linkcancellationdate} = 1;
      $cancelledreserve{modresnumber} = $modresnumber;
      my $modresborrower = GetMember($modresnumber);
      $cancelledreserve{modresfirstname} = $modresborrower->{'firstname'};
      $cancelledreserve{modressurname} = $modresborrower->{'surname'};
    }
    $cancelledreserve{biblionumber} = $res->{'biblionumber'};
    $cancelledreserve{reservedate} = format_date( $res->{'reservedate'} );
    $cancelledreserve{cancellationdate} = format_date( $res->{'cancellationdate'} );
    my $biblioData = GetBiblioData($res->{'biblionumber'});
    $cancelledreserve{reserves_title} = $biblioData->{'title'};
    _get_additional_item_info(\%cancelledreserve,$biblioData);
    push( @cancelledreservesloop, \%cancelledreserve );
}
$template->param( CANCELLEDRESERVES => \@cancelledreservesloop );
$template->param( cancelledreserves_count => scalar @cancelledreservesloop );

$template->param( holdhistoryview => 1 );

output_html_with_http_headers $query, $cookie, $template->output;

sub _get_additional_item_info {

  my ($reserve,$bibinfo) = @_;

  $reserve->{reserves_author} = $bibinfo->{'author'};
  my $marc = MARC::Record->new_from_usmarc($bibinfo->{'marc'});
  foreach my $subfield ( qw/b h n p/) {
    my $hashkey = "reserves_245" . $subfield;
    $reserve->{$hashkey} = $marc->subfield('245',$subfield)
      if (defined($marc->subfield('245',$subfield)));
  }
  if (defined($reserve->{'itemnumber'})) {
    my $item = GetItem($reserve->{'itemnumber'});
    $reserve->{callnumber} = $item->{'itemcallnumber'};
    $reserve->{enumchron}  = $item->{'enumchron'};
    $reserve->{copynumber} = $item->{'copynumber'};
  }
  return;
}
