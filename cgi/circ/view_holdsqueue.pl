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


=head1 view_holdsqueue

This script displays items in the tmp_holdsqueue and hold_fill_targets tables

=cut

use Koha;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Branch;
use C4::Reserves;

my $query          = CGI->new;
my $run_report     = $query->param('run_report');
my $run_pass       = $query->param('run_pass');
my $branchlimit    = $query->param('branchlimit')  // '';
my $limit          = 0;
my $currPage       = $query->param('currPage')     // 1;
my $orderby        = $query->param('orderby')      // 'tmp_holdsqueue.title';
my $offset         = 0;
my $total          = 0;
my $qitems         = [];

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
$template->param(
   currPage => $currPage,
   limit    => $limit,
);

if ($run_pass) {
   ($total,$qitems) = C4::Reserves::GetHoldsQueueItems(
      branch   => $branchlimit,
      offset   => $offset,
      limit    => $limit,
      orderby  => $orderby,
   );
   my $c = 0;
   my @qbranches = C4::Reserves::getBranchesQueueWeight();
   foreach my $item(@$qitems) {
      my $action = $query->param("action_$c") // '';
      my @actions = qw(pass trace);
      if ($action ~~ @actions) {
         my $res = C4::Reserves::GetReserve($$item{reservenumber});
         if    ($action eq 'pass')  { C4::Reserves::ModReservePass($res,@qbranches) }
         elsif ($action eq 'trace') { C4::Reserves::ModReserveTrace($res)}
      }
      $c++;
   }
   $run_report = 1;
}

if ($run_report) {
   $total  = 0;
   $qitems = [];
    ($total,$qitems) = C4::Reserves::GetHoldsQueueItems(
      branch => $branchlimit, 
      limit  => $limit,
      offset => $offset,
      orderby=> $orderby,
    );
    my $c = 0;
    foreach my $item(@$qitems) {
       $$item{action_cnt} = $c;
       my @qbranches = split(/\,/,$$item{queue_sofar});
       @qbranches    = reverse @qbranches;
       $qbranches[0] = "<i><b>$qbranches[0]</b></i>";
       $$item{branches_sentto} = join("<br>\n",@qbranches);
       $c++;
    }

    $template->param(
        itemsloop  => $qitems,
        run_report => $run_report,
        action_cnts=> $c,
        dateformat => C4::Context->preference("dateformat"),
    );
}

if ($run_report || $run_pass) {
   $template->param(
      total       => $total,
      from        => ($offset+1),
      to          => ($total< ($offset+$limit))? $total: ($offset+$limit),
      pager       => _pager($total, $limit, $currPage),
      branch      => $branchlimit || '',
      branchlimit => $branchlimit || '',
      branchname  => $branchlimit? C4::Branch::GetBranchName($branchlimit) : 'ALL',
      orderby     => $orderby,
   );
}
$template->param(
   branchloop => GetBranchesLoop(C4::Context->userenv->{'branch'}),
);

# writing the template
output_html_with_http_headers $query, $cookie, $template->output;
exit;

sub _pager
{
   my ($total, $limit, $currPage) = @_;
   my $out = '';
   return '' unless ($limit && $total);
   my $totalPages = $total%$limit? int($total/$limit)+1 : $total/$limit;
   return $out if $totalPages == 1;
   if ($currPage==1) {
      $out .= ' <b>1</b>';
   }
   else {
      my $prev = $currPage -1;
      $out = qq|<a href="javascript:;" onclick="pager(1)">&lt;&lt;</a> 
                <a href="javascript:;" onclick="pager($prev)">&lt;</a>
                <a href="javascript:;" onclick="pager(1)">1</a>|;
   }
   if ($currPage-2 >2) {
      $out .= ' ... ';
   }

   my $lastI = 0;
   for my $i($currPage-2..$currPage+2) {
      next if $i<2;
      if ($i==$currPage) {
         $out .= " <b>$i</b>";
      }
      else {
         $out .= qq| <a href="javascript:;" onclick="pager($i)">$i</a>|;
      }
      $lastI = $i;
      last if $i+1 >=$totalPages;
   }
   if ($currPage+3 < $totalPages) {
      $out .= ' ... ';
   }

   if ($currPage != $totalPages) {
      my $next = $currPage +1;
      $out .= qq| <a href="javascript:;" onclick="pager($totalPages);">$totalPages</a>|
      if $lastI != $totalPages;
      $out .= qq| <a href="javascript:;" onclick="pager($next);">&gt;</a> 
                  <a href="javascript:;" onclick="pager($totalPages);">&gt;&gt;</a>|;
   }
   else {
      $out .= " <b>$totalPages</b>" if $lastI != $totalPages;
   }

   return qq|<div style="font-size:10pt;">$out</div><br>|;
}

__END__
