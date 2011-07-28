#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;
use Koha::Plack::Util;

my $root = $ENV{PERL5LIB};
my $app = Plack::App::CGIBin->new(root => $root)->to_app;

use Koha::Squatting::Reserve  'On::PSGI';
use Koha::Squatting::Branch   'On::PSGI';
my $reserves = Koha::Squatting::Reserve->init;
my $branches = Koha::Squatting::Branch->init;

builder {
    enable 'Deflater';
    enable 'HTTPExceptions';
    enable 'MethodOverride';
    enable 'Status', path => qr{/C4/|/Koha/|/misc/|/t/|/xt/|/etc/}, status => 404;
    enable 'Static', path => qr{^/opac-tmpl/}, root => "$root/koha-tmpl/";
    enable 'Static', path => qr{^/intranet-tmpl/}, root => "$root/koha-tmpl/";
    enable 'Header', unset => ['Status'];
    enable '+Koha::Plack::Localize';
    enable '+Koha::Plack::Rewrite';

    mount '/branches/' => sub {Koha::Squatting::Branch->psgi(shift)};
    mount '/reserves/' => sub {Koha::Squatting::Reserve->psgi(shift)};
    mount '/' => $app;
};
