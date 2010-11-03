package C4::Model::DB::Object::AutoBase1;

use base 'Rose::DB::Object';

use C4::RoseDB;

sub init_db { C4::RoseDB->new() }

1;
