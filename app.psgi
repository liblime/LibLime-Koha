#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;
use Koha::Plack::Util;

my $app = Plack::App::CGIBin->new(root => $ENV{KOHA_BASE})->to_app;

builder {
    ### Enable if running behind an HTTP reverse proxy
    #enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'ReverseProxy';

    enable 'Deflater';

    ### Enable these if the front-end webserver is not setting
    ### "Expires" headers for static content already.
    #enable 'Expires',
    #    content_type => ['text/css', 'application/javascript', qr!^image/!],
    #        expires => 'access plus 1 day';

    enable 'Status', path => qr{/C4/|/Koha/|/misc/|/t/|/xt/|/etc/}, status => 404;
    enable 'Static', path => qr{^/opac-tmpl/}, root => 'koha-tmpl/';
    enable 'Static', path => qr{^/intranet-tmpl/}, root => 'koha-tmpl/';
    enable 'Header', unset => ['Status'];
    enable '+Koha::Plack::Localize';
    enable '+Koha::Plack::Rewrite';

    mount '/' => $app;
};
