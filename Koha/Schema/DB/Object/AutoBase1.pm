package Koha::Schema::DB::Object::AutoBase1;

use base 'Rose::DB::Object';

use Koha::RoseDB;

sub init_db { Koha::RoseDB->new() }

1;
