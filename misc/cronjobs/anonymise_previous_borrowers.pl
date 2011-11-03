#!/usr/bin/env perl

use Koha;
use C4::Context;
use C4::Circulation;

my $interval = C4::Context->preferece('KeepPreviousBorrowerInterval') // 30;
C4::Circulation::AnonymisePreviousBorrowers($interval);
