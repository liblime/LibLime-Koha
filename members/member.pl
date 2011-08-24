#!/usr/bin/env perl


#script to do a borrower enquiry/bring up borrower details etc
#written 20/12/99 by chris@katipo.co.nz


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
use C4::Members::AttributeTypes;
use C4::Members::Lists;
use C4::Branch;
use URI::Escape qw(uri_escape);

my $input = new CGI;
my $quicksearch = $input->param('quicksearch');
my $startfrom = $input->param('startfrom')||1;
my $resultsperpage = $input->param('resultsperpage')||C4::Context->preference("PatronsPerPage")||20;

my ($template, $loggedinuser, $cookie);
if($quicksearch){
    ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/member-quicksearch-results.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {borrowers => '*'},
                 debug => 1,
                 });
} else {
    ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/member.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {borrowers => '*'},
                 debug => 1,
                 });
}
my $theme = $input->param('theme') || "default";


$template->param( 
        "AddPatronLists_".C4::Context->preference("AddPatronLists")=> "1",
            );
if (C4::Context->preference("AddPatronLists")=~/code/){
    my $categories=GetBorrowercategoryList;
    $categories->[0]->{'first'}=1;
    $template->param(categories=>$categories);  
}  
            # only used if allowthemeoverride is set
#my %tmpldata = pathtotemplate ( template => 'member.tmpl', theme => $theme, language => 'fi' );
    # FIXME - Error-checking
#my $template = HTML::Template->new( filename => $tmpldata{'path'},
#                   die_on_bad_params => 0,
#                   loop_context_vars => 1 );

my $member = $input->param('member');
# trim leading and trailing whitespace from input
$member =~ s/^\s+//;
$member =~ s/\s+$//;

my $member_orig = $member;
my $orderby = $input->param('orderby');

$orderby = "surname,firstname" unless $orderby;
$member =~ s/,//g;   #remove any commas from search string
$member =~ s/\*/%/g;

my ($count,$results);

my $search_sql;

$template->param( 
 BorrowerListsLoop => GetLists(),
 SearchBorrowerListsLoop => GetLists({ selected => qq/$input->param('from_list_id')/ }),
);     

my $to;
my $currPage = $input->param('currPage') || 1;
my $offset;
my @adv_params;
if ( $input->param('advanced_patron_search') ) {  
  my $adv_params;
  $adv_params->{'borrowernumber'} = $input->param('borrowernumber') if ( $input->param('borrowernumber') );
  $adv_params->{'cardnumber'} = $input->param('cardnumber') if ( $input->param('cardnumber') );
  $adv_params->{'categorycode'} = $input->param('categorycode') if ( $input->param('categorycode') );
  $adv_params->{'dateenrolled_after'} = $input->param('dateenrolled_after') if ( $input->param('dateenrolled_after') );
  $adv_params->{'dateenrolled_before'} = $input->param('dateenrolled_before') if ( $input->param('dateenrolled_before') );
  $adv_params->{'dateexpiry_after'} = $input->param('dateexpiry_after') if ( $input->param('dateexpiry_after') );
  $adv_params->{'dateexpiry_before'} = $input->param('dateexpiry_before') if ( $input->param('dateexpiry_before') );
  $adv_params->{'branchcode'} = $input->param('branchcode') if ( $input->param('branchcode') );
  $adv_params->{'sort1'} = $input->param('sort1') if ( $input->param('sort1') || $input->param('sort1_empty') );
  $adv_params->{'sort2'} = $input->param('sort2') if ( $input->param('sort2') || $input->param('sort2_empty') );
  $adv_params->{'userid'} = $input->param('userid') if ( $input->param('userid') || $input->param('userid_empty') );
  $adv_params->{'dateofbirth_after'} = $input->param('dateofbirth_after') if ( $input->param('dateofbirth_after') );
  $adv_params->{'dateofbirth_before'} = $input->param('dateofbirth_before') if ( $input->param('dateofbirth_before') );
  $adv_params->{'surname'} = $input->param('surname') if ( $input->param('surname') );
  $adv_params->{'firstname'} = $input->param('firstname') if ( $input->param('firstname') );
  $adv_params->{'address'} = $input->param('address') if ( $input->param('address') );
  $adv_params->{'city'} = $input->param('city') if ( $input->param('city') );
  $adv_params->{'zipcode'} = $input->param('zipcode') if ( $input->param('zipcode') );
  $adv_params->{'B_address'} = $input->param('B_address') if ( $input->param('B_address') );
  $adv_params->{'B_city'} = $input->param('B_city') if ( $input->param('B_city') );
  $adv_params->{'B_zipcode'} = $input->param('B_zipcode') if ( $input->param('B_zipcode') );
  $adv_params->{'email'} = $input->param('email') if ( $input->param('email') || $input->param('email_empty') );
  $adv_params->{'emailpro'} = $input->param('emailpro') if ( $input->param('emailpro') || $input->param('emailpro_empty') );
  $adv_params->{'phone'} = $input->param('phone') if ( $input->param('phone') || $input->param('phone_empty') );
  $adv_params->{'opacnotes'} = $input->param('opacnotes') if ( $input->param('opacnotes') );
  $adv_params->{'borrowernotes'} = $input->param('borrowernotes') if ( $input->param('borrowernotes') );

  $adv_params->{'debarred'} = 1 if ( $input->param('debarred') );
  $adv_params->{'gonenoaddress'} = 1 if ( $input->param('gonenoaddress') );
  $adv_params->{'lost'} = 1 if ( $input->param('lost') );
  
  $adv_params->{'list_id'} = $input->param('from_list_id') if ( $input->param('from_list_id') );

  $adv_params->{'orderby'} = $input->param('orderby') if ( $input->param('orderby') );
  $adv_params->{'limit'}   = $input->param('limit') || 20;
  $adv_params->{'offset'}  = $input->param('offset') || 0;

  my @attributes = C4::Members::AttributeTypes::GetAttributeTypes();
  foreach my $a ( @attributes ) {
        $adv_params->{'attributes'}->{ $a->{'code'} } = $input->param( $a->{'code'} ) if ( $input->param( $a->{'code'} ) );
  }

  my $cgi_params = $input->Vars;
  delete $cgi_params->{'orderby'};
  delete $cgi_params->{'limit'};
  delete $cgi_params->{'offset'};
  $template->param( %$cgi_params );
  
  foreach my $k ( keys %$cgi_params ) {
    my $t;
    $t->{'name'} = $k;
    $t->{'value'} = $cgi_params->{$k};
    push( @adv_params, $t );
  }
  $template->param( AdvancedSearchParametersLoop => \@adv_params );
  $startfrom          = 1;
  $$adv_params{limit} = $resultsperpage;
  $$adv_params{offset}= ($currPage -1)*$resultsperpage;
  $offset             = $$adv_params{offset};
  ($count, $results)  = SearchMemberAdvanced( $adv_params );

  ## Add results to a borrower list, if neccessary
  if ( $input->param('add_to_list') ) {
    my $list_id = $input->param('list_id');

    unless ( $list_id ) {
      my $list_name = $input->param('list_name');
      $list_id = CreateList({ list_name => $list_name });
    }

    foreach my $r ( @$results ) {
      my $borrowernumber = $r->{'borrowernumber'};
      AddBorrowerToList({
        list_id => $list_id,
        borrowernumber => $borrowernumber
      });
    }
  }
} elsif ( $input->param('sqlsearch') ) {
  $search_sql = 'SELECT * FROM borrowers LEFT JOIN categories ON borrowers.categorycode = categories.categorycode WHERE ';
  my @parts = split( /;/, $input->param('sqlsearch') );
  $search_sql .= $parts[0];
  $template->param( member => $search_sql );
  ($count, $results) = SearchMemberBySQL( $search_sql );
}
else {
    my $type = (length($member) == 1) ? 'simple' : 'advanced';
    my $startfrom = $input->param('startfrom') // 1;
    my $offset = ($startfrom-1) * $resultsperpage;
    my $limits
        = {
            offset => $offset,
            limit  => $resultsperpage,
          };
    ($count, $results) = SearchMember($member, $orderby, $type, undef, $limits);
    # we prepend a bunch of empty elements into the array so that the PATRON loop
    # below can start out with $i at the offset.
    unshift @$results, map {undef} (1..$limits->{offset});
}

my @resultsdata;
$to ||=($count>($startfrom*$resultsperpage)?$startfrom*$resultsperpage:$count);

PATRON:
for (my $i=($startfrom-1)*$resultsperpage; $i < $to; $i++){
  last PATRON unless $$results[$i];
  #find out stats
  my ($od,$issue,$fines)=GetMemberIssuesAndFines($results->[$i]{'borrowernumber'});

  no warnings qw(uninitialized);
  my %row = (
    count => $i+1,
    borrowernumber => $results->[$i]{'borrowernumber'},
    cardnumber => $results->[$i]{'cardnumber'},
    PreviousCardnumber => $results->[$i]{'PreviousCardnumber'},
    surname => $results->[$i]{'surname'},
    firstname => $results->[$i]{'firstname'},
    initials => $results->[$i]{'initials'},
    categorycode => $results->[$i]{'categorycode'},
    category_type => $results->[$i]{'category_type'},
    category_description => $results->[$i]{'description'},
    address => $results->[$i]{'address'},
	address2 => $results->[$i]{'address2'},
    city => $results->[$i]{'city'},
	zipcode => $results->[$i]{'zipcode'},
	country => $results->[$i]{'country'},
    branchcode => $results->[$i]{'branchcode'},
    overdues => $od,
    issues => $issue,
    odissue => "$od/$issue",
    fines =>  sprintf("%.2f",$fines),
    borrowernotes => $results->[$i]{'borrowernotes'},
    sort1 => $results->[$i]{'sort1'},
    sort2 => $results->[$i]{'sort2'},
    dateexpiry => C4::Dates->new($results->[$i]{'dateexpiry'},'iso')->output('syspref'),
    );
  push(@resultsdata, \%row);
}

my $base_url =
    'member.pl?'
  . join(
    '&',
    map { $_->{term} . '=' . $_->{val} } (
        { term => 'member', val => $member_orig},
        { term => 'orderby', val => $orderby },
        { term => 'resultsperpage', val => $resultsperpage },
        { term => 'type',           val => 'intranet' },
    )
  );

foreach my $a ( @adv_params ) {
  my $name = $a->{'name'};
  next if $name eq 'currPage';
  next if $name eq 'advanced_patron_search';

  my $value = $a->{'value'};
  $base_url .= uri_escape("&$name=$value");
}
if ( $input->param('advanced_patron_search') && $count) {
   my $pg   = $input->param('currPage') || 1;
   my $from = ($count>$resultsperpage)?($resultsperpage*($pg-1))+1 : 1;
   $to      = ($from+$resultsperpage)>$count? $count : $from+$resultsperpage;
   $template->param(
      paginationbar => _adv_pagination($count, $resultsperpage, $currPage),
      startfrom     => $startfrom,
      from          => $from,
      to            => $to,
      resultsperpage=> $resultsperpage,
      multipage     => ($count>$resultsperpage)? 1:0,
      currPage      => $pg,
      offset        => $offset,
   );
}
else {
   ## FIXME: use SQL for paging instead of truncated results set
   $template->param(
      paginationbar => pagination_bar(
         $base_url,  int( $count / $resultsperpage ) + 1,
         $startfrom, 'startfrom'
      ),
      startfrom => $startfrom,
      from      => ($startfrom-1)*$resultsperpage+1,  
      to        => $to,
      multipage => ($count != $to || $startfrom!=1),
   );
}

$template->param( 
        searching       => "1",
        member          => $member_orig,
        numresults      => $count,
        resultsloop     => \@resultsdata,
            );

$template->param( ShowPatronSearchBySQL => C4::Context->preference('ShowPatronSearchBySQL') );

if ( $input->param('sqlsearch') ) {
  $template->param( member => $search_sql );
}
$template->param("showinitials" => C4::Context->preference('DisplayInitials'));

## Advanced Patron Search
my @attributes = C4::Members::AttributeTypes::GetAttributeTypes() if ( C4::Context->preference('ExtendedPatronAttributes') );
foreach my $a ( @attributes ) { $a->{'value'} = $input->param( $a->{'code'} ); }

my $cat = GetBorrowercategoryList();
foreach(@$cat) {
   if ($$_{categorycode} ~~ $input->param('categorycode')) {
      $$_{selected} = 1;
      last;
   }
}

my $branchesloop = GetBranchesLoop($input->param('branchcode'));
if (!$input->param('branchcode')) {
    map {delete $_->{selected}} @{$branchesloop};
}

$template->param(
    CategoriesLoop => $cat,
    BranchesLoop => $branchesloop,
    AttributesLoop => \@attributes,
);

output_html_with_http_headers $input, $cookie, $template->output;
exit;

sub _adv_pagination
{
   my ($count, $resultsperpage, $currPage) = @_;
   my $out = '';
   my $totalPages = $count%$resultsperpage? int($count/$resultsperpage)+1 : $count/$resultsperpage;
   if ($currPage==1) {
      $out .= ' <b>1</b>';
   }
   else {
      my $prev = $currPage -1;
      $out = qq|<a href="javascript:;" onclick="goAdv(1)">&lt;&lt;</a> 
                <a href="javascript:;" onclick="goAdv($prev)">&lt;</a>
                <a href="javascript:;" onclick="goAdv(1)">1</a>|;
   }
   if ($currPage-2 >2) {
      $out .= ' ... ';
   }
   for my $i($currPage-2..$currPage+2) {
      next if $i<2;
      if ($i==$currPage) {
         $out .= " <b>$i</b>";
      }
      else {
         $out .= qq| <a href="javascript:;" onclick="goAdv($i)">$i</a>|;
      }
      last if $i+1 >=$totalPages;
   }
   if ($currPage+3 < $totalPages) {
      $out .= ' ... ';
   }

   if ($currPage != $totalPages) {
      my $next = $currPage +1;
      $out .= qq| <a href="javascript:;" onclick="goAdv($totalPages);">$totalPages</a>
                  <a href="javascript:;" onclick="goAdv($next);">&gt;</a> 
                  <a href="javascript:;" onclick="goAdv($totalPages);">&gt;&gt;</a>|;
   }
   else {
      $out .= " <b>$totalPages</b>";
   }

   return $out;
}

__END__
