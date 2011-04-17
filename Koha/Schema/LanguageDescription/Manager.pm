package Koha::Schema::LanguageDescription::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LanguageDescription;

sub object_class { 'Koha::Schema::LanguageDescription' }

__PACKAGE__->make_manager_methods('language_descriptions');

1;

