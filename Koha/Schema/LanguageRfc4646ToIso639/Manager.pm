package Koha::Schema::LanguageRfc4646ToIso639::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::LanguageRfc4646ToIso639;

sub object_class { 'Koha::Schema::LanguageRfc4646ToIso639' }

__PACKAGE__->make_manager_methods('language_rfc4646_to_iso639');

1;

