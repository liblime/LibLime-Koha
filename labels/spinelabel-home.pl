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
use C4::Context;
use C4::Labels::Lib qw(get_all_layouts get_all_profiles);
use C4::Circulation;
# use Smart::Comments;

my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "labels/spinelabel-home.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
        debug           => 1,
    }
);

# get session cookies or also CGI input
my %in;
foreach(qw(layout_id profile_id prefix)) {
   $in{$_} = $query->param($_) || $query->cookie($_);
}
my $barcode = $query->param('barcode');
my $bclen   = C4::Context->preference('itembarcodelength');
if ($bclen && length($barcode)<$bclen) {
   $barcode = C4::Circulation::barcodedecode(barcode=>$barcode);
}
$template->param(
   barcode     => $barcode || '',
   layout_id   => $query->param('layout_id')  || 0,
   profile_id  => $query->param('profile_id') || 0,
   layouts     => _sel('layout_id',get_all_layouts(),%in),
   profiles    => _sel('profile_id',get_all_profiles(),%in),
   prefixes    => _sel('prefix',[
      { prefix=>'_none' ,name=>'None'              },
      { prefix=>'LOC'   ,name=>'Shelving Location' },
      { prefix=>'CCODE' ,name=>'Collection Code'   },
   ],%in),
);
output_html_with_http_headers $query, $cookie, $template->output;

no warnings qw(redefine);

sub _sel
{
   my($f,$a,%in) = @_;
   foreach(@$a) {
      if ($$_{$f} ~~ $in{$f}) {
         $$_{_sel} = 'selected';
      }
      else {
         $$_{_sel} = '';
      }
   }
   return $a;
}

