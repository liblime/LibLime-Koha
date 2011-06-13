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

use warnings;
use strict;
use CGI;
use C4::Auth;
use C4::Output;
use Koha;
use C4::Context;
use C4::Labels::Label;
use C4::Labels::Layout;

my $query  = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "labels/spinelabel-print.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
        debug           => 1,
    }
);

my $barcode = $query->param('barcode');
my $bclen   = C4::Context->preference('itembarcodelength');
if ($bclen && length($barcode)<$bclen) {
   $barcode = C4::Circulation::barcodedecode(barcode=>$barcode);
}
my $dbh = C4::Context->dbh;
my $sth;
my $item = C4::Labels::Label::GetQuickItemFromBarcode($barcode);
unless ($item) {
  $template->param( 'Barcode' => $barcode );
  $template->param( 'BarcodeNotFound' => 1 );
}

## get the layout and prefix so we'll know how to print this
my $layout_id = $query->param('layout_id')  || $query->cookie('layout_id');
my $profile_id= $query->param('profile_id') || $query->cookie('profile_id');
my $prefix    = $query->param('prefix')     || $query->cookie('prefix');
my $layout    = new C4::Labels::Layout;
my $lay       = $layout->retrieve(layout_id=>$layout_id);

## set the cookie
my $cookie1 = $query->cookie(
   -name => 'layout_id',   -value=>$layout_id);
my $cookie2 = $query->cookie(
   -name => 'profile_id',  -value=>$profile_id);
my $cookie3 = $query->cookie(
   -name => 'prefix',      -value=>$prefix);
# this won't disturb cookies already set
$cookie = [$cookie1,$cookie2,$cookie3];

my @all;
foreach my $f(split(/\,/, $$lay{format_string})) {
   my @tmp;
   $f =~ s/^\s+//g; $f =~ s/\s+$//g; # trim wrapping spaces
   if ($f eq 'itemcallnumbr') {
      @tmp = _split(
         $$item{itemcallnumber},
         $$lay{callnum_split},
         $$lay{break_rule_string}
      );
   }
#   elsif ($f eq 'author') {
#      @tmp = _split(
#         $$item{author},
#         'author'
#      );
#   }
#   elsif ($f eq 'title') {
#      @tmp = _split(
#         $$item{title},
#         'title'
#      );
#   }
   elsif (grep /^$f$/, keys %$item) {
      @tmp = ($$item{$f});
   }
   elsif ($f) {
      @tmp = ($f);
   }
   push @all, join(' ',@tmp);
}

if ($prefix ne '_none') {
   # get authorised value
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare(q|
      SELECT id,authorised_value,prefix
      FROM   authorised_values
      WHERE  category=?
   |) || die $dbh->errstr;
   $sth->execute($prefix);

   PREFIX:
   while(my $row = $sth->fetchrow_hashref()) {
      if ($prefix eq 'LOC') {
         if ($$item{location} eq $$row{authorised_value}) {
            unshift @all, $$row{prefix};
            last PREFIX;
         }
      }
      elsif ($prefix eq 'CCODE') {
         if ($$item{ccode} eq $$row{authorised_value}) {
            unshift @all, $$row{prefix};
            last PREFIX;
         }
      }
   }
}

my @body;
foreach(@all) {
   next unless $_;
   push @body, $_;
}

# fonts support
my %fonts = (
   TR => ['times'       ,''      ,''      ], #font,weight,style
   TB => ['times'       ,'bold'  ,''      ],
   TI => ['times'       ,''      ,'italic'],
   TBI=> ['times'       ,'bold'  ,'italic'],
   C  => ['courier'     ,''      ,''      ],
   CB => ['courier'     ,'bold'  ,''      ],
   CO => ['courier'     ,''      ,'italic'],# oblique
   CBO=> ['courier'     ,'bold'  ,'italic'],
   CN => ['courier new' ,''      ,''      ],
   CNB=> ['courier new' ,'bold'  ,''      ],
   CNI=> ['courier new' ,'bold'  ,'italic'],
   H  => ['helvetica'   ,''      ,''      ],
   HB => ['helvetica'   ,'bold'  ,''      ],
   HBO=> ['helvetica'   ,'bold'  ,'italic'],
);

# text justification
 my %aline = (
   L  => 'left',
   C  => 'center',
   R  => 'right'
);
# put it all together
my $beg = sprintf(qq|<table border=0 cellspacing=0 cellpadding=0><tr><td>
   <div style="font-family:%s;font-weight:%s;font-style:%s,font-size:%spt;
   border:%spx %s red;text-align:%s">|,
   $fonts{$$lay{font}}[0],
   $fonts{$$lay{font}}[1],
   $fonts{$$lay{font}}[2],
   $$lay{font_size},
   $$lay{guidebox} ? 1:0,
   $$lay{guidebox} ? 'solid' : 'none',
   $aline{$$lay{text_justify}},
);
my $end = '</div></td></tr></table>';

$template->param( autoprint => C4::Context->preference('SpineLabelAutoPrint') );
$template->param( 
   content     => $beg . join("<br>\n",@body) . $end,
   layout_id   => $query->param('layout_id'),
   profile_id  => $query->param('profile_id'),
   prefix      => $query->param('prefix'),
);

output_html_with_http_headers $query, $cookie, $template->output;
exit;

sub _split
{
   my($s,$how,$re) = @_;
   my @p;
   if ($how eq 'custom')   { @p = C4::Labels::Label::_split_custom($s,$re) }
   elsif ($how eq 'lccn')  { @p = C4::Labels::Label::_split_lccn($s)       }
   elsif ($how eq 'ddcn')  { @p = C4::Labels::Label::_split_ddcn($s)       }
   elsif ($how eq 'author'){ @p = C4::Labels::Label::_split_author($s)     }
   elsif ($how eq 'title') { @p = C4::Labels::Label::_split_title($s)      }
   return join('', @p);
}


__END__
#my $scheme = C4::Context->preference('SpineLabelFormat');
my $data;
while ( my ( $key, $value ) = each(%$item) ) {
    $data->{$key} .= "<span class='field' id='$key'>";

    $value = '' unless defined $value;
    my @characters = split( //, $value );
    my $charnum    = 1;
    my $wordnum    = 1;
    my $i          = 1;
    foreach my $char (@characters) {
        if ( $char ne ' ' ) {
            $data->{$key} .= "<span class='character word$wordnum character$charnum' id='$key$i'>$char</span>";
        } else {
            $data->{$key} .= "<span class='space character$charnum' id='$key$i'>$char</span>";
            $wordnum++;
            $charnum = 1;
        }
        $charnum++;
        $i++;
    }

    $data->{$key} .= "</span>";
}

while ( my ( $key, $value ) = each(%$data) ) {
    $scheme =~ s/<$key>/$value/g;
}

$body = $scheme;


