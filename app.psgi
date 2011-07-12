#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;
use Koha::Plack::Util;

my $app = Plack::App::CGIBin->new(root => $ENV{PERL5LIB})->to_app;

use Koha::Squatting::Reserve 'On::PSGI';
my $reserves = Koha::Squatting::Reserve->init;
builder {
    enable 'HTTPExceptions';
    enable 'MethodOverride';
    enable 'Deflater';
    enable 'Static', path => qr{^/opac-tmpl/}, root => 'koha-tmpl/';
    enable 'Static', path => qr{^/intranet-tmpl/}, root => 'koha-tmpl/';
    enable '+Koha::Plack::Localize';
    enable '+Koha::Plack::Rewrite';
    enable '+Koha::Plack::ScrubStatus';

    mount '/reserves/' => sub {Koha::Squatting::Reserve->psgi(shift)};
    mount '/' => $app;
};
