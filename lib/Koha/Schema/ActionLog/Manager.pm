package Koha::Schema::ActionLog::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::ActionLog;

sub object_class { 'Koha::Schema::ActionLog' }

__PACKAGE__->make_manager_methods('action_logs');

1;

