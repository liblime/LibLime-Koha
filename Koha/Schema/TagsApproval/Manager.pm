package Koha::Schema::TagsApproval::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::TagsApproval;

sub object_class { 'Koha::Schema::TagsApproval' }

__PACKAGE__->make_manager_methods('tags_approval');

1;

