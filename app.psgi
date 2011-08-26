#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;
use Koha::Plack::Util;

my $root = $ENV{KOHA_BASE} // '.';

my $main_app = Plack::App::CGIBin->new(root => $root)->to_app;
my $svc_app = Plack::App::CGIBin->new(root => "$root/svc", exec_cb => sub{1})->to_app;

use Koha::Squatting::Reserve  'On::PSGI';
use Koha::Squatting::Branch   'On::PSGI';
my $reserves = Koha::Squatting::Reserve->init;
my $branches = Koha::Squatting::Branch->init;

builder {
    enable \&Koha::Plack::Util::PrefixFhOutput;

    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'ReverseProxy';

    enable 'Deflater';
    enable 'HTTPExceptions';
    enable 'MethodOverride';

    enable 'Static', path => qr{^/opac-tmpl/}, root => "$root/koha-tmpl/";
    enable 'Static', path => qr{^/intranet-tmpl/}, root => "$root/koha-tmpl/";

    enable 'Status', path => qr{/C4/|/Koha/|/misc/|/t/|/xt/|/etc/}, status => 404;
    enable 'Rewrite', rules => \&Koha::Plack::Util::RedirectRootAndOpac;

    enable_if { return (Plack::Request->new(shift)->cookies()->{debug} // 0) != 0 }
        'Debug', panels => [
            qw(Environment Response Timer Memory Session),
            ['DBIProfile', profile => 2],
            ];

    enable 'Header', unset => ['Status'];
    enable '+Koha::Plack::Localize';

    mount '/branches/' => sub {Koha::Squatting::Branch->psgi(shift)};
    mount '/reserves/' => sub {Koha::Squatting::Reserve->psgi(shift)};
    mount '/cgi-bin/koha/' => $main_app;
    mount '/svc/' => $svc_app;
};
