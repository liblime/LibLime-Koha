#!/usr/bin/env perl

use strict;
use warnings;

use Koha::RoseDB;
use Rose::DB::Object::Loader;

use Data::Dumper;

my $loader = Rose::DB::Object::Loader->new(
      db           => Koha::RoseDB->new(),
      class_prefix => 'Koha::Schema',
      exclude_tables => ['class_sources', 'opac_news', 'subscription', 'serial', 'serialitems', 'subscription_defaults', 'subscription_serial_items', 'subscriptionhistory', 'subscriptionroutinglist'],
      #include_tables => [ 'periodicals', 'periodical_serials', 'subscriptions', 'subscription_serials', 'biblio', 'biblioitems', 'items' ],
    );

#my @classes = $loader->make_classes;
#printf Dumper \@classes;

$loader->make_modules(
#    module_dir => '/home/ctftest2'
);
