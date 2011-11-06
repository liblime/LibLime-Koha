package Koha::Schema::Branch;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
   table   => 'branches',

   columns => [
      branchcode           => { type => 'varchar', length=>10, not_null => 1 },
      branchname           => { type => 'scalar', length => 16777215 , not_null => 1 },
      branchaddress1       => { type => 'scalar', length => 16777215              },
      branchaddress2       => { type => 'scalar', length => 16777215              },
      branchaddress3       => { type => 'scalar', length => 16777215              },
      branchzip            => { type => 'varchar' , length=>25   },
      branchcity           => { type => 'scalar', length => 16777215              },
      branchcountry        => { type => 'text'                   },
      branchphone          => { type => 'scalar', length => 16777215              },
      branchfax            => { type => 'scalar', length => 16777215              },
      branchemail          => { type => 'scalar', length => 16777215              },
      branchurl            => { type => 'scalar', length => 16777215              },
      issuing              => { type => 'tinyint' , length=>4    },
      branchip             => { type => 'text'                   },
      branchprinter        => { type => 'varchar' , length=>100  },
      branchnotes          => { type => 'scalar', length => 16777215              },
      patronbarcodeprefix  => { type => 'char'    , length=>15   },
      itembarcodeprefix    => { type => 'char'    , length=>19   },
      branchonshelfholds   => { type => 'tinyint' , length=>1,   default=>1, not_null=>1 }
    ],

    primary_key_columns => [ 'branchcode' ],

#    foreign_keys => [],
);

1;

