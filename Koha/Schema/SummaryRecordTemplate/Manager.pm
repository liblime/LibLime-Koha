package Koha::Schema::SummaryRecordTemplate::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Koha::Schema::SummaryRecordTemplate;

sub object_class { 'Koha::Schema::SummaryRecordTemplate' }

__PACKAGE__->make_manager_methods('summary_record_templates');

1;

