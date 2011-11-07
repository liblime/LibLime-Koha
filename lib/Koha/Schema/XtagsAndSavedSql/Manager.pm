package Koha::Schema::XtagsAndSavedSql::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::XtagsAndSavedSql;

sub object_class { 'Koha::Schema::XtagsAndSavedSql' }

__PACKAGE__->make_manager_methods('xtags_and_saved_sql');

1;

