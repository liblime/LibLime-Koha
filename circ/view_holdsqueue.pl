#!/usr/bin/perl

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


=head1 view_holdsqueue

This script displays items in the tmp_holdsqueue and hold_fill_targets tables

=cut

use strict;
use warnings;
use CGI;
use C4::Auth;
use C4::Output;
#use C4::Items;
#use C4::Koha;   # GetItemTypes
use C4::Branch;
use C4::Reserves;

my $query          = new CGI;
my $run_report     = $query->param('run_report');
my $run_pass       = $query->param('run_pass');
my $branchlimit    = $query->param('branchlimit');
my $itemtypeslimit = $query->param('itemtypeslimit');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'circ/view_holdsqueue.tmpl',
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

if ($run_pass) {
   my $qitems = C4::Reserves::GetHoldsQueueItems($branchlimit, $itemtypeslimit);
   my $c = 0;
   my %items = ();

   foreach my $item(@$qitems) {
      my $res = C4::Reserves::GetReserve($$item{reservenumber});
      if ($query->param("action_$c") eq 'pass') {
         C4::Reserves::ModReservePass($res);
      }
      elsif ($query->param("action_$c") eq 'trace') {
         C4::Reserves::ModReserveTrace($res);
      }
      $c++;
   }
   $run_report = 1;
}

if ($run_report) {
    my $items = C4::Reserves::GetHoldsQueueItems($branchlimit, $itemtypeslimit);
    my $c = 0;
    foreach my $item(@$items) {
       $$item{action_cnt} = $c;
       my @qbranches = split(/\,/,$$item{queue_sofar});
       @qbranches    = reverse @qbranches;
       $qbranches[0] = "<i><b>$qbranches[0]</b></i>";
       $$item{branches_sentto} = join("<br>\n",@qbranches);
       $c++;
    }

    $template->param(
        branch     => $branchlimit,
        total      => scalar @$items,
        itemsloop  => $items,
        run_report => $run_report,
        action_cnts=> $c,
        dateformat => C4::Context->preference("dateformat"),
        branchlimit=> $branchlimit,
    );
}

$template->param(
     branchloop => GetBranchesLoop(C4::Context->userenv->{'branch'}),
#   itemtypeloop => \@itemtypesloop,
);

# writing the template
output_html_with_http_headers $query, $cookie, $template->output;
exit;
__END__
