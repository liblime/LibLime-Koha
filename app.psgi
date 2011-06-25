#!/usr/bin/env perl

use Koha;
use Plack::App::CGIBin;
use Plack::Builder;

my $app = Plack::App::CGIBin->new(root => $ENV{PERL5LIB})->to_app;

sub is_staff {
    my $env = shift;

    my ($hostname) = split(/, /, $env->{HTTP_X_FORWARDED_HOST}//$env->{HTTP_HOST});
    $hostname //= $env->{SERVER_NAME};
                          
    return $hostname =~ /-staff\./;
}

builder {
    enable 'Deflater';
    enable 'Static', path => qr{^/opac-tmpl/}, root => 'koha-tmpl/';
    enable 'Static', path => qr{^/intranet-tmpl/}, root => 'koha-tmpl/';
    enable '+Koha::Plack::Localize';
    enable '+Koha::Plack::Rewrite', staff_resolver => \&is_staff;
    enable '+Koha::Plack::ScrubStatus';

    mount '/' => $app;
};
