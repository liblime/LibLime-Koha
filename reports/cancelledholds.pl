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

use strict;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Reports;
use C4::Members;
use C4::Reserves;
use C4::Dates;
use C4::Branch;

=head1 NAME

plugin that shows cancelled holds

=head1 DESCRIPTION

=over 2

=cut

my $input = new CGI;
my $fullreportname = "reports/cancelledholds.tmpl";

my $do_it      = $input->param('do_it');
my $patron     = $input->param('patron')        || undef;
my $fromdate   = $input->param('from')          || undef;
my $todate     = $input->param('to')            || undef;
my $holdcandate= $input->param('holdcandate')   || undef;
my $branchcode = $input->param('branch')        || undef;
my $output     = $input->param("output");
my $basename   = $input->param("basename");
my $mime       = $input->param("MIME");
our $sep       = $input->param("sep");
$sep           = "\t" if ($sep eq 'tabulation');
my $branches   = C4::Branch::GetBranchesLoop();
my ($template, $borrowernumber, $cookie) = get_template_and_user(
        { template_name => $fullreportname,
          query => $input,
          type => "intranet",
          authnotrequired => 0,
          flagsrequired => {circulate => 1},
          debug => 1,
        });
$template->param(do_it => $do_it,
   DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
);
$template->param(branchloop => $branches);

if ($do_it) {
   # Obtain results
   my @rows = @{C4::Reports::CancelledHolds(
      patron      => $patron,
      fromdate    => $fromdate,
      todate      => $todate,
      holdcandate => $holdcandate,
      branchcode  => $branchcode,
   )};
   die "More than 1000 rows: needs refactoring to page, KNOWN ISSUE"
      if @rows > 1000;
   my @headers = ();
   foreach(@rows) {
      $$_{status} = '';
      if ($$_{found}) { 
         $$_{status} = $C4::Reserves::found{$$_{found}};
      }
   }
   # Displaying results
   if ($output eq "screen") {
      # Printing results to screen
      $template->param(results => \@rows);
      output_html_with_http_headers $input, $cookie, $template->output;
      exit;
   }
   else {
   # Printing to a csv file
    print $input->header(-type => 'application/vnd.sun.xml.calc',
                         -encoding    => 'utf-8',
                         -attachment=>"$basename.csv",
                         -filename=>"$basename.csv" );
   # Print column headers
   @headers = (
      ['ResNo.'   ,   'reservenumber'   ],
      ['Title'    ,   'title'           ],
      ['Biblionumber','biblionumber'    ],
      ['Cardnumber',  'cardnumber'      ],
      ['Last Name',,  'surname'         ],
      ['First Name',  'firstname'       ],
      ['Placed On',   'reservedate'     ],
      ['Cancelled',   'cancellationdate'],
      ['Expired',     'expirationdate'  ],
      ['Library',     'branchname'      ],
      ['Last Status', 'status'          ],
    );
    foreach( @headers ) {
      print $$_[0].$sep;
    }
    print "\n";
   # Print table
    foreach my $row ( @rows ) {
      print join($sep,map{$$row{$$_[1]}}@headers);
      print "$sep\n";
    }
    exit;
  }
# Displaying choices

exit;
}
  
my @mime = ( C4::Context->preference("MIME") );
my $CGIextChoice=CGI::scrolling_list(
                -name     => 'MIME',
                -id       => 'MIME',
                -values   => \@mime,
                -size     => 1,
                -multiple => 0 );

my $CGIsepChoice = GetDelimiterChoices;
my ($codes,$labels) = GetborCatFromCatType(undef,undef);
my(@borcatloop,$labels);
foreach my $thisborcat (sort keys %$labels) {
   my %row =(value => $thisborcat,
       description => $labels->{$thisborcat});
    push @borcatloop, \%row;
}
$template->param(
     CGIextChoice => $CGIextChoice,
     CGIsepChoice => $CGIsepChoice,
     borcatloop =>\@borcatloop,
);
output_html_with_http_headers $input, $cookie, $template->output;
exit;
__END__
