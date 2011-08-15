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

sub is_staff {
    my $hostname = Koha::Plack::Util::GetCanonicalHostname(shift);
    return $hostname =~ /-staff\./;
}

builder {
    enable 'Deflater';
    enable 'HTTPExceptions';
    enable 'MethodOverride';

    enable 'Static', path => qr{^/opac-tmpl/}, root => "$root/koha-tmpl/";
    enable 'Static', path => qr{^/intranet-tmpl/}, root => "$root/koha-tmpl/";

    enable 'Status', path => qr{/C4/|/Koha/|/misc/|/t/|/xt/|/etc/}, status => 404;
    enable 'Rewrite', rules => sub {
        my $env = shift;
        return 302 if (is_staff($env) && s{^/$}{/cgi-bin/koha/mainpage.pl});
        return 302 if (!is_staff($env) && s{^/$}{/cgi-bin/koha/opac-main.pl});
        if (!is_staff($env)) { s{^/cgi-bin/koha/}{/cgi-bin/koha/opac/}}
        return;
    };

    enable 'Header', unset => ['Status'];
    enable '+Koha::Plack::Localize';

    mount '/branches/' => sub {Koha::Squatting::Branch->psgi(shift)};
    mount '/reserves/' => sub {Koha::Squatting::Reserve->psgi(shift)};
    mount '/cgi-bin/koha/' => $main_app;
    mount '/svc/' => $svc_app;
};
