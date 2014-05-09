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

my $re = $cgi->param('r');
my $t = $cgi->param('t');
$template->param(
    t => $t,
    s => join '<br>', ($t =~ m/$re/gx),
);

output_html_with_http_headers $cgi,$cookie,$template->output;
