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

This script displays items in the tmp_holdsqueue table

=cut

use strict;
use warnings;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
#use C4::Koha;   # GetItemTypes
use C4::Branch; # GetBranches
use C4::Reserves;

my $query          = new CGI;
my $run_report     = $query->param('run_report');
my $run_fill       = $query->param('run_fill');
my $run_trace      = $query->param('run_trace');
my $branchlimit    = $query->param('branchlimit');
my $itemtypeslimit = $query->param('itemtypeslimit');
my $tmpl           = 'view_holdsqueue';
$tmpl              = 'view_holdstrace' if ($run_fill || $run_trace);

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/$tmpl.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

# apparently, perl doesn't want a variable called 'do_trace'
if ($run_trace) {
   my $dbh = C4::Context->dbh;
   my @traces = $query->param('trace');
   
   # get all branches, just the branchcode
   my @branches  = _getBranchQueue();
   my $numtraced = 0;
   TRACE:
   foreach my $trace(@traces) {
      my($biblionumber,$borrowernumber,$itemnumber) = split('_',$trace,3);
      my $reserverec = C4::Reserves::GetReserveInfo($borrowernumber,$biblionumber);
      C4::Reserves::ModReserveTrace($reserverec);

      # update the database w/ the next library and level
      my $level   = $query->param("level_$trace");
      my($nextlib)= $query->param("nextlib_$trace") =~ /<b><i>(\w+)</;
      $level++;
      if ($level < @branches) {
         my $sth = $dbh->prepare("UPDATE hold_fill_targets
            SET item_level_request= ?,
                source_branchcode = ?
          WHERE borrowernumber    = ?
            AND biblionumber      = ?
            AND itemnumber        = ?") || die $dbh->errstr();
         $sth->execute($level,$nextlib,$borrowernumber,$biblionumber,$itemnumber);
         $sth = $dbh->prepare("UPDATE tmp_holdsqueue
            SET   item_level_request = ?
            WHERE borrowernumber     = ?
            AND   biblionumber       = ?
            AND   itemnumber         = ?") || die $dbh->errstr();
         $sth->execute($level,$borrowernumber,$biblionumber,$itemnumber);
      }
      $numtraced++;
   }
   # set output
   my $numnotraced = $query->param('cnt_notrace');
   $template->param(
      numtraced      =>$numtraced,
      numnotraced    =>$numnotraced,
      traced_plural  =>$numtraced==1?'':'s',
      notraced_plural=>$numnotraced==1?'':'s',
      run_trace   =>1,
   );
}
elsif ($run_fill) {
   my $qitems = C4::Reserves::GetHoldsQueueItems($branchlimit, $itemtypeslimit);
   my @items; # leave undef
   my $c = 0;
   my $numfilled = 0;

   # get the libraries queue
   my @branches = _getBranchQueue();

   foreach my $item(@$qitems) {
      if ($query->param("action_$c") eq 'fill') {
         my $reserverec = C4::Reserves::GetReserveInfo(
            $$item{borrowernumber},
            $$item{biblionumber}
         );
         C4::Reserves::ModReserveFill($reserverec);
         $numfilled++;
      }
      elsif ($query->param("action_$c") eq 'pass') {
         # figure out the pass to libraries queue so far
         my @q;
         my @q = ($$item{pickbranch});
         for my $i(0..$$item{item_level_request}) {
            unshift @q, $branches[$i] unless
            $$item{pickbranch} eq $branches[$i];
         }
         $q[0] = "<b><i>$q[0]</i></b>";
         $$item{passedto} = join('<br>',@q);
         $$item{nextlib}  = $q[0];
         push @items, $item;
      }
      $c++;
   }
   $template->param(
      numfilled   => $numfilled,
      items       => \@items,
      plurality   => $numfilled==1?'hold was':'holds were',
      run_fill    => $run_fill,
   );
}
elsif ($run_report) {
    my $items = C4::Reserves::GetHoldsQueueItems($branchlimit, $itemtypeslimit);
    my $c = 0;
    foreach my $item(@$items) {
       $$item{action_cnt} = $c;
       $c++;
    }
    $template->param(
        branch     => $branchlimit,
        total      => scalar @$items,
        itemsloop  => $items,
        run_report => $run_report,
        action_cnts=> $c,
        dateformat => C4::Context->preference("dateformat"),
    );
}

# getting all itemtypes
#my $itemtypes = &GetItemTypes();
#my @itemtypesloop;
#foreach my $thisitemtype ( sort keys %$itemtypes ) {
#    push @itemtypesloop, {
#        value       => $thisitemtype,
#        description => $itemtypes->{$thisitemtype}->{'description'},
#    };
#}

$template->param(
     branchloop => GetBranchesLoop(C4::Context->userenv->{'branch'}),
#   itemtypeloop => \@itemtypesloop,
);

# writing the template
output_html_with_http_headers $query, $cookie, $template->output;

sub _getBranchQueue
{
   my @branches;
   my $nextpref   = C4::Context->preference('NextLibraryHoldsQueueWeight');
   my $staypref   = C4::Context->preference('StaticHoldsQueueWeight');
   my $dorand     = C4::Context->preference('RandomizeHoldsQueueWeight');
   my $numtraced  = 0;
   if ($nextpref) {
      @branches = split(/\,\s*/,$nextpref);
   }
   else {
      if ($staypref) {
         @branches = split(/\,\s*/,$staypref);
      }
      else {
         @branches = keys %{C4::Branch::GetBranches() || {}};
      }
      if ($dorand) {
         use List::Util 'shuffle';
         @branches = shuffle(@branches);
      }
   }
   @branches;
}
