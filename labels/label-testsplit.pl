#!/usr/bin/env perl

use strict;
use CGI;
use C4::Auth qw(get_template_and_user);
use C4::Output qw(output_html_with_http_headers);

my $cgi = new CGI;
my($template,$loggedinuser,$cookie) = get_template_and_user(
   {
      template_name  => 'labels/label-testsplit.tmpl',
      query          => $cgi,
      type           => 'intranet',
      authnotrequired=> 0,
      flagsrequired  => { catalogue=>1 },
      debug          => 0,

   }
);
$template->param(
   t  => $cgi->param('t'),
   s  => join('<br>',_split($cgi->param('t'))),
);
output_html_with_http_headers $cgi,$cookie,$template->output;
exit;

sub _split
{
   my $t = shift;
   my $re= $cgi->param('r');
   $_    = $t;
   my @parts = ();
   eval{@parts = m/$re/x;};
   return @parts;
}
