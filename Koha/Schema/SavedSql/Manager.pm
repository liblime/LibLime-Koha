package Koha::Schema::SavedSql::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SavedSql;

sub object_class { 'Koha::Schema::SavedSql' }

__PACKAGE__->make_manager_methods('saved_sql');

1;

