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

use C4::Dates qw/format_date/;
my $input = CGI->new();

my ($template, $loggedinuser, $cookie) = get_template_and_user({template_name => "members/readingrec.tmpl",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired => {borrowers => '*'},
				debug => 1,
				});

my $borrowernumber=$input->param('borrowernumber');
#get borrower details
my $data=GetMember($borrowernumber,'borrowernumber');
my $order=$input->param('order') || '';
my $order2=$order;
if ($order2 eq ''){
  $order2="date_due desc";
}
my $limit=$input->param('limit');

if ($limit){
    if ($limit eq 'full'){
		$limit=0;
    }
} 
else {
  $limit=50;
}
my ($count,$issues)=GetAllIssues($borrowernumber,$order2,$limit);

my @loop_reading;

for (my $i=0;$i<$count;$i++){
 	my %line;
	$line{biblionumber}=$issues->[$i]->{'biblionumber'};
	$line{title}=$issues->[$i]->{'title'};
	$line{author}=$issues->[$i]->{'author'};
	$line{classification} = $issues->[$i]->{'classification'} || $issues->[$i]->{'itemcallnumber'};
	$line{date_due}=format_date($issues->[$i]->{'date_due'});
	$line{returndate}=format_date($issues->[$i]->{'returndate'});
	$line{renewals}=$issues->[$i]->{'renewals'};
	$line{barcode}=$issues->[$i]->{'barcode'};
	$line{volumeddesc}=$issues->[$i]->{'volumeddesc'};	
	$line{issuedate}=C4::Dates->new($issues->[$i]->{'issuedate'},'iso')->output;
	( $line{charge} ) = sprintf( "%.2f", C4::Circulation::GetIssuingCharges( $issues->[$i]->{'itemnumber'}, $borrowernumber ) );
	$line{replacementprice}=$issues->[$i]->{'replacementprice'};
	$line{itemtype}=$issues->[$i]->{'itemtype'};
	push(@loop_reading,\%line);
}

if ( $data->{'category_type'} eq 'C') {
    my  ( $catcodes, $labels ) =  GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
    my $cnt = scalar(@$catcodes);
    $template->param( 'CATCODE_MULTI' => 1) if $cnt > 1;
    $template->param( 'catcode' =>    $catcodes->[0])  if $cnt == 1;
}

$template->param( adultborrower => 1 ) if ( $data->{'category_type'} eq 'A' );
if (! $limit){ 
	$limit = 'full'; 
}

my ($picture, $dberror) = GetPatronImage($data->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

$template->param(
						readingrecordview => 1,
						biblionumber => $data->{'biblionumber'},
						title => $data->{'title'},
						initials => $data->{'initials'},
						surname => $data->{'surname'},
						borrowernumber => $borrowernumber,
						limit => $limit,
						firstname => $data->{'firstname'},
						cardnumber => $data->{'cardnumber'},
					    categorycode => $data->{'categorycode'},
					    category_type => $data->{'category_type'},
					   # category_description => $data->{'description'},
					    categoryname	=> $data->{'description'},
					    address => $data->{'address'},
						address2 => $data->{'address2'},
					    city => $data->{'city'},
						zipcode => $data->{'zipcode'},
						country => $data->{'country'},
						phone => $data->{'phone'},
						email => $data->{'email'},
			   			branchcode => $data->{'branchcode'},
			   			is_child        => ($data->{'category_type'} eq 'C'),
			   			branchname => GetBranchName($data->{'branchcode'}),
						showfulllink => ($count > 50),					
						loop_reading => \@loop_reading);

## Get reserves placed and canceled.
my $dbh = C4::Context->dbh;
my $query = "SELECT * , DATE_FORMAT(statistics.datetime, '%m/%d/%Y') AS date_formatted
	     FROM statistics LEFT JOIN biblio on statistics.other = biblio.biblionumber 
	     WHERE ( statistics.type = 'reserve' OR statistics.type = 'reserve_canceled' )
	     AND borrowernumber = ?
	     ORDER BY datetime DESC
	     ";
my $sth = $dbh->prepare( $query );
$sth->execute( $borrowernumber );
my $reserve_stats = $sth->fetchall_arrayref({});
$template->param( reserves_stats_loop => $reserve_stats );

## Get notices sent
$query = "SELECT * , DATE_FORMAT(statistics.datetime, '%m/%d/%Y') AS date_formatted
	     FROM statistics LEFT JOIN letter on statistics.other = letter.code	     
	     WHERE statistics.type = 'notice_sent'
	     AND borrowernumber = ?
	     ORDER BY datetime DESC
	     ";
$sth = $dbh->prepare( $query );
$sth->execute( $borrowernumber );
my $notices_sent_stats = $sth->fetchall_arrayref({});
$template->param( notices_sent_stats_loop => $notices_sent_stats );

## Get patron blocks
$query = "SELECT *
	     FROM borrower_edits
	     WHERE borrowernumber = ?
             AND field NOT LIKE '%note%'
	     ORDER BY timestamp DESC
	     ";
$sth = $dbh->prepare( $query );
$sth->execute( $borrowernumber );
#my $patron_edit_stats = $sth->fetchall_arrayref({});
my $patron_edit_stats = [];
while (my $row = $sth->fetchrow_hashref()) {
   if ($$row{field} eq 'password') {
      $$row{before_value} = '****';
      $$row{after_value}  = '****';
   }
   push @$patron_edit_stats, $row;
}
$template->param( patron_edit_stats_loop => $patron_edit_stats );

## Get patron blocks
$query = "SELECT *
             FROM messages
	     WHERE (messages.auth_value LIKE 'A_%'
                 OR messages.auth_value LIKE 'B_%'
                 OR messages.message LIKE 'Unblocked%')
	     AND borrowernumber = ?
	     ORDER BY message_date DESC
	     ";
$sth = $dbh->prepare( $query );
$sth->execute( $borrowernumber );
my $patron_block_stats = $sth->fetchall_arrayref({});
$template->param( patron_block_stats_loop => $patron_block_stats );

output_html_with_http_headers $input, $cookie, $template->output;
