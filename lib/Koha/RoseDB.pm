package Koha::RoseDB;

use Rose::DB;
use Koha;
use C4::Context;
our @ISA = qw(Rose::DB);

# Use a private registry for this class
__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(
      domain   => __PACKAGE__->default_domain,
      type     => __PACKAGE__->default_type,
      driver   => 'mysql',
      database => C4::Context->config('database'),
      host     => C4::Context->config('hostname'),
      port     => C4::Context->config('port'),
      username => C4::Context->config('user'),
      password => C4::Context->config('pass'),
      connect_options => {
          RaiseError => 1,
          AutoCommit => 1,
      },
);

1;
