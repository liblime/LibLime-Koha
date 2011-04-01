#!/usr/bin/env perl

use Modern::Perl;
use Plack::App::CGIBin;
use Plack::Builder;
use Data::Dumper;

my $app = Plack::App::CGIBin->new(root => $ENV{PERL5LIB})->to_app;

my $svc = sub {
    my $env = shift;
    return [200, [ 'Content-type' => 'text/plain' ], [Dumper [$env, \%ENV]] ];
};

builder {
    enable 'Deflater';
    enable 'Static', path => qr{^/opac-tmpl/}, root => 'koha-tmpl/';
    enable 'Static', path => qr{^/intranet-tmpl/}, root => 'koha-tmpl/';
    enable '+C4::Plack::Localize';
    enable '+C4::Plack::Rewrite';
    enable '+C4::Plack::ScrubStatus';

    mount '/' => $app;
    mount '/svc2' => $svc;
};
