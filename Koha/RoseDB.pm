package Koha::RoseDB;

use Rose::DB;
use C4::Context;
our @ISA = qw(Rose::DB);

# Use a private registry for this class
__PACKAGE__->use_private_registry;

my $context = C4::Context->new;

__PACKAGE__->register_db(
      driver   => 'mysql',
      database => $context->config('database'),
      host     => $context->config('hostname'),
      port     => $context->config('port'),
      username => $context->config('user'),
      password => $context->config('pass'),
);

1;
