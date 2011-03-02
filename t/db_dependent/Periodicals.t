#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

BEGIN {
    use_ok('C4::Control::Periodical');
    use_ok('C4::Control::PeriodicalSerial');
    use_ok('C4::Control::Subscription');
    use_ok('C4::View::Serials');
}

my $template = HTML::Template->new(filename => '/dev/null', die_on_bad_params => 0);

isa_ok(C4::View::Serials::SeedTemplateWithGeneralData($template),                            'HTML::Template');
isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalData($template, 1),                      'HTML::Template');
isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, issn => '1234'),       'HTML::Template');
isa_ok(C4::View::Serials::SeedTemplateWithPeriodicalSearch($template, title => 'something'), 'HTML::Template');
isa_ok(C4::View::Serials::SeedTemplateWithSubscriptionData($template, 1),                    'HTML::Template');

exit 0;
