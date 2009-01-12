package C4::Schema::Result::Branches;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("branches");
__PACKAGE__->add_columns(
  "branchcode",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 10 },
  "branchname",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 0,
    size => 16777215,
  },
  "branchaddress1",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "branchaddress2",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "branchaddress3",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "branchphone",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "branchfax",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "branchemail",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "issuing",
  { data_type => "TINYINT", default_value => undef, is_nullable => 1, size => 4 },
  "branchip",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 15,
  },
  "branchprinter",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "itembarcodeprefix",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
  "patronbarcodeprefix",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
);
__PACKAGE__->add_unique_constraint("branchcode", ["branchcode"]);
__PACKAGE__->has_many(
  "borrowers",
  "C4::Schema::Result::Borrowers",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "branch_item_rules",
  "C4::Schema::Result::BranchItemRules",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "branchrelations",
  "C4::Schema::Result::Branchrelations",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "branchtransfers_frombranches",
  "C4::Schema::Result::Branchtransfers",
  { "foreign.frombranch" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "branchtransfers_tobranches",
  "C4::Schema::Result::Branchtransfers",
  { "foreign.tobranch" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "circ_policies",
  "C4::Schema::Result::CircPolicies",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "circ_rules",
  "C4::Schema::Result::CircRules",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "circ_termsets",
  "C4::Schema::Result::CircTermsets",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "default_branch_circ_rules",
  "C4::Schema::Result::DefaultBranchCircRules",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "hold_fill_targets",
  "C4::Schema::Result::HoldFillTargets",
  { "foreign.source_branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "issues",
  "C4::Schema::Result::Issues",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "items_homebranches",
  "C4::Schema::Result::Items",
  { "foreign.homebranch" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "items_holdingbranches",
  "C4::Schema::Result::Items",
  { "foreign.holdingbranch" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "library_hours",
  "C4::Schema::Result::LibraryHours",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "old_issues",
  "C4::Schema::Result::OldIssues",
  { "foreign.branchcode" => "self.branchcode" },
);
__PACKAGE__->has_many(
  "reserves",
  "C4::Schema::Result::Reserves",
  { "foreign.branchcode" => "self.branchcode" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-02-17 07:25:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:80aZRYgcYDusRiaIYvGtPA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
