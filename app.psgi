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
    enable 'HTTPExceptions';
    enable 'MethodOverride';
    enable 'Deflater';
    enable 'Static', path => qr{^/opac-tmpl/}, root => "$root/koha-tmpl/";
    enable 'Static', path => qr{^/intranet-tmpl/}, root => "$root/koha-tmpl/";
    enable '+Koha::Plack::Localize';
    enable '+Koha::Plack::Rewrite';
    enable '+Koha::Plack::ScrubStatus';

    mount '/branches/' => sub {Koha::Squatting::Branch->psgi(shift)};
    mount '/reserves/' => sub {Koha::Squatting::Reserve->psgi(shift)};
    mount '/' => $app;
};
