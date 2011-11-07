#!/usr/bin/env perl

# Copyright 2011 PTFS/Liblime
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

my $cgi = new CGI;
my $fullreportname = "reports/holdsaction.tmpl";

my $go         = $cgi->param('go');
my $branchcode = $cgi->param('branch')        || undef;
my $output     = $cgi->param('output');
my $basename   = $cgi->param('basename');
my $mime       = $cgi->param('MIME');
our $sep       = $cgi->param('sep');
$sep           = "\t" if ($sep eq 'tabulation');
my ($template, $borrowernumber, $cookie) = get_template_and_user(
        { template_name => $fullreportname,
          query => $cgi,
          type => "intranet",
          authnotrequired => 0,
          flagsrequired => {reserveforothers => 1},
          debug => 1,
        });
$template->param(
   go                       => $go,
   DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
   branchloop               => C4::Branch::GetBranchesLoop(),
);

## high-level sanity check.
unless (C4::Context->preference('ReservesMaxPickupDelay')) {
   $template->param(novarset => 1);
   output_html_with_http_headers $cgi, $cookie, $template->output;
   exit;
}

if ($go) {
   my @reservenumbers = $cgi->param('lapsed');
   C4::Reserves::UnshelfLapsed(@reservenumbers);
   my @rows = @{C4::Reports::HoldsShelf(
      branchcode  => $branchcode,
   )};
   if ($output eq "screen") {
      # Printing results to screen
      $template->param(
         results     => \@rows,
         branchcode  => $branchcode,
      );
      output_html_with_http_headers $cgi, $cookie, $template->output;
      exit;
   }
   else {
      print $cgi->header(-type      => 'application/vnd.sun.xml.calc',
                         -encoding  => 'utf-8',
                         -attachment=>"$basename.csv",
                         -filename  =>"$basename.csv" );
   # Print column headers
      my @headers = (
         ['ResNo.'   ,   'reservenumber'     ],
         ['Title'    ,   'title'             ],
         ['Biblionumber','biblionumber'      ],
         ['Cardnumber',  'cardnumber'        ],
         ['Last Name',,  'surname'           ],
         ['First Name',  'firstname'         ],
         ['Placed On',   'reservedate'       ],
         ['Expires',     'expirationdate'    ],
         ['Cancelled',   'cancellationdate'  ],
         ['Library',     'branchname'        ],
      );
      foreach( @headers ) {
         print $$_[0].$sep;
      }
      print "\n";
      foreach my $row ( @rows ) {
         print join($sep,map{$$row{$$_[1]}}@headers);
         print "$sep\n";
      }
      exit;
   }
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
output_html_with_http_headers $cgi, $cookie, $template->output;
exit;
__END__
