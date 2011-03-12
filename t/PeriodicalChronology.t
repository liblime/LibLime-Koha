#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 27;
use DateTime;

use_ok('C4::Model::Periodical::Chronology');

my $chron1 = C4::Model::Periodical::Chronology->new(pattern => '%q %Y');
ok($chron1);

ok($chron1->format_datetime(DateTime->new(year=>2010, month=>1)) eq 'Winter 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>2)) eq 'Winter 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>3)) eq 'Spring 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>4)) eq 'Spring 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>5)) eq 'Spring 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>6)) eq 'Summer 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>7)) eq 'Summer 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>8)) eq 'Summer 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>9)) eq 'Fall 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>10)) eq 'Fall 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>11)) eq 'Fall 2010');
ok($chron1->format_datetime(DateTime->new(year=>2010, month=>12)) eq 'Winter 2010');

my $chron2 = C4::Model::Periodical::Chronology->new(pattern => '%Q %Y');
ok($chron2);

ok($chron2->format_datetime(DateTime->new(year=>2010, month=>1)) eq 'Summer 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>2)) eq 'Summer 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>3)) eq 'Fall 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>4)) eq 'Fall 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>5)) eq 'Fall 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>6)) eq 'Winter 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>7)) eq 'Winter 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>8)) eq 'Winter 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>9)) eq 'Spring 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>10)) eq 'Spring 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>11)) eq 'Spring 2010');
ok($chron2->format_datetime(DateTime->new(year=>2010, month=>12)) eq 'Summer 2010');

exit 0;
