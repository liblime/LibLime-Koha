package Koha::Schema::ProxyRelationship::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ProxyRelationship;

sub object_class { 'Koha::Schema::ProxyRelationship' }

__PACKAGE__->make_manager_methods('proxy_relationships');

1;

