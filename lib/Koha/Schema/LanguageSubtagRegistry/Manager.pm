package Koha::Schema::LanguageSubtagRegistry::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LanguageSubtagRegistry;

sub object_class { 'Koha::Schema::LanguageSubtagRegistry' }

__PACKAGE__->make_manager_methods('language_subtag_registry');

1;

