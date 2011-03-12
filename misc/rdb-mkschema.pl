#!/usr/bin/env perl

use strict;
use warnings;

use C4::RoseDB;
use Rose::DB::Object::Loader;

use Data::Dumper;

my $loader = Rose::DB::Object::Loader->new(
      db           => C4::RoseDB->new(),
      class_prefix => 'C4::Schema',
      #exclude_tables => ['class_sources', 'opac_news'],
      include_tables => [ 'periodicals', 'periodical_serials', 'subscriptions', 'subscription_serials', 'biblio', 'biblioitems', 'items' ],
    );

#my @classes = $loader->make_classes;
#printf Dumper \@classes;

$loader->make_modules(
#    module_dir => '/home/ctftest2'
);
