#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;

my $app = Plack::App::CGIBin->new(root => $ENV{PERL5LIB})->to_app;

builder {
    enable 'Deflater';
    enable 'Static', path => qr{^/opac-tmpl/}, root => 'koha-tmpl/';
    enable 'Static', path => qr{^/intranet-tmpl/}, root => 'koha-tmpl/';
    enable '+C4::Plack::Localize';
    enable '+C4::Plack::Rewrite';
    enable '+C4::Plack::ScrubStatus';

    mount '/' => $app;
};
