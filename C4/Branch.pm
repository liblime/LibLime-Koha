package C4::Branch;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA


use strict;
use warnings;
use Carp;
use Storable;
use List::MoreUtils qw(uniq);
use Net::CIDR::Compare;

require Exporter;

use C4::Context;
use C4::Koha;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
	# set the version for version checking
	$VERSION = 3.02;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&GetBranchCategory
		&GetBranchName
		&GetBranch
		&GetBranches
		&GetBranchesLoop
		&GetBranchDetail
		&get_branchinfos_of
		&ModBranch
		&CheckBranchCategorycode
		&GetBranchInfo
		&GetCategoryTypes
		&GetBranchCategories
		&GetBranchesInCategory
		&ModBranchCategoryInfo
		&DelBranch
		&DelBranchCategory
	);
	@EXPORT_OK = qw( &onlymine &mybranch GetBranchCodeFromName GetSiblingBranchesOfType );
}

=head1 NAME

C4::Branch - Koha branch module

=head1 SYNOPSIS

use C4::Branch;

=head1 DESCRIPTION

The functions in this module deal with branches.

=head1 FUNCTIONS

=head2 GetBranches

  $branches = &GetBranches();

  Returns informations about ALL branches, IndependantBranches Insensitive.
  GetBranchInfo() returns the same information without the problems of this function 
  (namespace collision, mainly).
  Create a branch selector with the following code.
  
=head3 in PERL SCRIPT

    my $branches = GetBranches;
    my @branchloop;
    foreach my $thisbranch (sort keys %$branches) {
        my $selected = 1 if $thisbranch eq $branch;
        my %row =(value => $thisbranch,
                    selected => $selected,
                    branchname => $branches->{$thisbranch}->{branchname},
                );
        push @branchloop, \%row;
    }

=head3 in TEMPLATE

    <select name="branch">
        <option value="">Default</option>
        <!-- TMPL_LOOP name="branchloop" -->
        <option value="<!-- TMPL_VAR name="value" -->" <!-- TMPL_IF name="selected" -->selected<!-- /TMPL_IF -->><!-- TMPL_VAR name="branchname" --></option>
        <!-- /TMPL_LOOP -->
    </select>

=head4 Note that you often will want to just use GetBranchesLoop, for exactly the example above.

=cut

my $branches_cache;

sub _clear_branches_cache {
    $branches_cache = undef;
}

sub _seed_branches_cache {
    my $dbh = C4::Context->dbh;

    my $branches = $dbh->selectall_hashref(
        'SELECT * FROM branches ORDER BY branchname',
        'branchcode');

    my $groups = $dbh->selectall_hashref(
        'SELECT branchcode, categorycode FROM branchrelations',
        ['branchcode', 'categorycode']);

    for my $branch (values %$branches) {
        my @branchcategories = keys %{$groups->{$branch->{branchcode}}};
        $branch->{category} = {map {$_=>1} @branchcategories};
    }

    return $branches_cache = Storable::freeze($branches);
}

sub GetAllBranches {
    # return a copy of the cache hash so mutations from the caller
    # don't generate side-effects
    return Storable::thaw($branches_cache //= _seed_branches_cache());
}

sub GetBranchcodes {
    my $sorter = shift // sub { $a->{branchcode} cmp $b->{branchcode}};
    
    my @branchcodes = map {$_->{branchcode}} sort $sorter values %{GetAllBranches()};
    return wantarray ? @branchcodes : \@branchcodes;
}

sub GetBranches {
    my ($onlymine, $branchcode) = @_;

    my $branches = GetAllBranches();
    if ($onlymine) {
        $branchcode = (C4::Context->userenv) ? C4::Context->userenv->{branch} : undef;
    }

    return ($branchcode)
        ? {$branchcode => $branches->{$branchcode}}
        : $branches;
}

sub onlymine {
    return 
    C4::Context->preference('IndependantBranches') &&
    C4::Context->userenv                           &&
    C4::Context->userenv->{flags} %2 != 1          &&
    C4::Context->userenv->{branch}                 ;
}

# always returns a string for OK comparison via "eq" or "ne"
sub mybranch {
    C4::Context->userenv           or return '';
    return C4::Context->userenv->{branch} || '';
}

sub GetBranchesLoop (;$$) {  # since this is what most pages want anyway
    my $branch   = @_ ? shift : mybranch();     # optional first argument is branchcode of "my branch", if preselection is wanted.
    my $onlymine = @_ ? shift : onlymine();
    my $branches = GetBranches($onlymine);
    my @loop;
    foreach (sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} } keys %$branches) {
        push @loop, {
            value => $_,
            selected => ($_ ~~ $branch) ? 1 : 0, 
            branchname => $branches->{$_}->{branchname},
        };
    }
    return \@loop;
}

=head2 GetBranchName

=cut

sub GetBranchName {
    my $branchcode = shift or return;
    return GetBranches()->{$branchcode}{branchname};
}

=head2 ModBranch

$error = &ModBranch($newvalue);

This function creates a new or modifies an existing branch depending on the 
existence of the hash key 'add' in the supplied parameter.

C<$newvalue> is a ref to an hash containing  any columns from the branches table to be updated.
FIXME: This code also allows passing category codes as hash keys.  There is a namespace collision
problem here.  

=cut

sub ModBranch {
    my ($data) = @_;
    my @columns = qw/branchname branchaddress1 branchaddress2 branchaddress3
                     branchzip branchcity branchcountry branchphone branchfax
                     branchemail branchurl issuing branchip branchprinter
                     branchnotes branchonshelfholds itembarcodeprefix
                     patronbarcodeprefix/;
    
    my $dbh    = C4::Context->dbh;
    my (@qterms, @bind, $sth);
    if ($data->{add}) {
        for my $col ( @columns ) {
            if(exists($data->{$col})) {
                push @qterms, $col;
                push @bind, $data->{$col};
            }
        }
        push @qterms, 'branchcode';
        my $query  = " INSERT INTO branches (" . join(',',@qterms) .  ") VALUES (" . join(',', map { '?' } @qterms) . ")";
        $sth    = $dbh->prepare($query);

    } else {
        for my $col ( @columns ) {
            if(exists($data->{$col}) && ($col ne 'branchcode')) {
                push @qterms, "$col=?";
                push @bind, $data->{$col};
            }
        }
        my $query  = " UPDATE branches SET " . join(',',@qterms) .  " WHERE branchcode=?";
        $sth    = $dbh->prepare($query);
    }
    $sth->execute(@bind, $data->{branchcode}) or die "Cannot add branch: " . $dbh->errstr;
    # sort out the categories....
    my @checkedcats;
    my $cats = GetBranchCategory();
    foreach my $cat (@$cats) {
        my $code = $cat->{'categorycode'};
        if ( $data->{$code} ) {
            push( @checkedcats, $code );
        }
    }
    my $branchcode = uc( $data->{'branchcode'} );
    my $branch     = GetBranchInfo($branchcode);
    $branch = $branch->[0];
    my $branchcats = $branch->{'categories'};
    my @addcats;
    my @removecats;
    foreach my $bcat (@$branchcats) {

        unless ( grep { /^$bcat$/ } @checkedcats ) {
            push( @removecats, $bcat );
        }
    }
    foreach my $ccat (@checkedcats) {
        unless ( grep { /^$ccat$/ } @$branchcats ) {
            push( @addcats, $ccat );
        }
    }
    foreach my $cat (@addcats) {
        my $sth =
          $dbh->prepare(
"insert into branchrelations (branchcode, categorycode) values(?, ?)"
          );
        $sth->execute( $branchcode, $cat );
        $sth->finish;
    }
    foreach my $cat (@removecats) {
        my $sth =
          $dbh->prepare(
            "delete from branchrelations where branchcode=? and categorycode=?"
          );
        $sth->execute( $branchcode, $cat );
        $sth->finish;
    }

    _clear_branches_cache();
}

=head2 GetBranchCategory

$results = GetBranchCategory($categorycode);

C<$results> is an ref to an array.

=cut

my $bcat_cache;

sub _clear_bcat_cache {
    $bcat_cache = undef;
}

sub _seed_bcat_cache {
    my $bcats = C4::Context->dbh->selectall_hashref(
        'SELECT * FROM branchcategories', 'categorycode');
    return $bcat_cache = Storable::freeze($bcats);
}

sub GetAllBranchCategories {
    # return a copy of the cache hash to protect against mutation
    return Storable::thaw($bcat_cache //= _seed_bcat_cache());
}

sub GetBranchCategory {
    my ($catcode) = @_;

    my $categories = GetAllBranchCategories();

    return ($catcode)
        ? [$categories->{$catcode}]
        : [map {$_} values %$categories];
}

=head2 GetBranchCategories

  my $categories = GetBranchCategories($branchcode,$categorytype);

Returns a list ref of anon hashrefs with keys eq columns of branchcategories table,
i.e. categorycode, categorydescription, categorytype, categoryname.
if $branchcode and/or $categorytype are passed, limit set to categories that
$branchcode is a member of , and to $categorytype.

=cut

sub _sort_by_type_then_by_code {
    return $a->{categorytype} cmp $b->{categorytype}
        || $a->{categorycode} cmp $b->{categorycode};

}

sub GetBranchCategories {
    my ($branchcode, $categorytype) = @_;

    my $cats = [values %{GetAllBranchCategories()}];

    if ($branchcode) {
        my $branch = GetBranches(undef, $branchcode);
        $cats = [grep {$branch->{$branchcode}->{category}{$_->{categorycode}}} @$cats];
    }
    if ($categorytype) {
        $cats = [grep {$_->{categorytype} eq $categorytype} @$cats];
    }

    $cats = [sort _sort_by_type_then_by_code @$cats];

    return $cats;
}

=head2 GetCategoryTypes

$categorytypes = GetCategoryTypes;
returns a list of category types.
Currently these types are HARDCODED.
type: 'searchdomain' defines a group of agencies that the calling library may search in.
Other usage of agency categories falls under type: 'properties'.
	to allow for other uses of categories.
The searchdomain bit may be better implemented as a separate module, but
the categories were already here, and minimally used.
=cut

	#TODO  manage category types.  rename possibly to 'agency domains' ? as borrowergroups are called categories.
sub GetCategoryTypes() {
	return ( 'searchdomain','properties', 'subscriptions', 'patrons');
}

=head2 CategoryTypeIsUsed

  if (CategoryTypeIsUsed($my_category)) {
      ...
  }

If the specified category type has any member categories defined, this
function returns 1. Otherwise it returns 0.

=cut

sub CategoryTypeIsUsed {
    my $categorytype = shift;

    return (@{GetBranchCategories(undef, $categorytype)} != 0) ? 1 : 0;
}

=head2 GetSiblingBranchesOfType

  my @branchcodes = GetMyBranchesForType($branchcode, $categorytype);

The "My" in this case refers to the provided $branchcode. This returns an array of
branchcodes that are in one or more of the branchcategories which are members of
the same category as $branchcode and of type $categorytype.

It will always return a list of at least one branchcode, the one specified in
the args. If a category type is not used, it will include *all* of the
defined branchcodes.

=cut

sub GetSiblingBranchesOfType {
    my ($branchcode, $categorytype) = @_;
    croak 'Poorly formatted parameters' if !($branchcode && $categorytype);

    my @branchcodes;
    if (CategoryTypeIsUsed($categorytype)) {
        @branchcodes = ($branchcode);
        for my $cat (@{GetBranchCategories($branchcode, $categorytype)}) {
            push @branchcodes, @{GetBranchesInCategory($cat->{categorycode})};
        }
        @branchcodes = uniq @branchcodes;
    }
    else {
        @branchcodes = sort keys %{GetAllBranches()};
    }

    return @branchcodes;
}

=head2 GetBranch

$branch = GetBranch( $query, $branches );

=cut

sub GetBranch ($$) {
    my ( $query, $branches ) = @_;    # get branch for this query from branches
    my $branch = $query->param('branch');
    my %cookie = $query->cookie('userenv');
    $branch ||= $cookie{'branchname'};

    if(!$branch || ($branch && !$branches->{$branch})) {
        $branch = (keys %$branches)[0];
    }

    return $branch;
}

=head2 GetBranchDetail

    $branch = &GetBranchDetail($branchcode);

Given the branch code, the function returns a
hashref for the corresponding row in the branches table.

=cut

sub GetBranchDetail {
    my ($branchcode) = shift || return;

    my $branch = GetBranches(undef, $branchcode);
    return if not defined $branch->{$branchcode};
    my %branch = %{$branch->{$branchcode}};
    delete $branch{category}; # Not sure if keeping this will break callers
    return \%branch;
}

=head2 get_branchinfos_of

  my $branchinfos_of = get_branchinfos_of(@branchcodes);

Associates a list of branchcodes to the information of the branch, taken in
branches table.

Returns a href where keys are branchcodes and values are href where keys are
branch information key.

  print 'branchname is ', $branchinfos_of->{$code}->{branchname};

=cut

sub get_branchinfos_of {
    my @branchcodes = @_;

    my $query = '
    SELECT branchcode,
       branchname
    FROM branches
    WHERE branchcode IN ('
      . join( ',', map( { "'" . $_ . "'" } @branchcodes ) ) . ')
';
    return C4::Koha::get_infos_of( $query, 'branchcode' );
}


=head2 GetBranchesInCategory

  my $branches = GetBranchesInCategory($categorycode);

Returns a href:  keys %$branches eq (branchcode,branchname) .

=cut

sub GetBranchesInCategory {
    my ($categorycode) = @_;

    my $branches = GetBranches();
    my @catbranches;
    for my $branch (values %$branches) {
        if ($branch->{category}{$categorycode}) {
            push @catbranches, $branch->{branchcode};
        }
    }
    return \@catbranches;
}

=head2 GetBranchInfo

$results = GetBranchInfo($branchcode);

returns C<$results>, a reference to an array of hashes containing branches.
if $branchcode, just this branch, with associated categories.
=cut

sub GetBranchInfo {
    my $branchcode = shift;

    my @branches = values %{GetBranches(undef, $branchcode)};
    for my $branch (@branches) {
        $branch->{categories} = [map {$_} keys %{$branch->{category}}];
        delete $branch->{category};
    }
    return \@branches;
}

=head2 DelBranch

&DelBranch($branchcode);

=cut

sub DelBranch {
    my ($branchcode) = @_;
    my $sth = C4::Context->dbh->do(
        'DELETE FROM branches WHERE branchcode = ?', undef, $branchcode);
    _clear_branches_cache();
}

=head2 ModBranchCategoryInfo

&ModBranchCategoryInfo($data);
sets the data from the editbranch form, and writes to the database...

=cut

sub ModBranchCategoryInfo {
    my ($data) = @_;
    my $dbh    = C4::Context->dbh;
	if ($data->{'add'}){
		# we are doing an insert
		my $sth   = $dbh->prepare("INSERT INTO branchcategories (categorycode,categoryname,codedescription,categorytype) VALUES (?,?,?,?)");
		$sth->execute(uc( $data->{'categorycode'} ),$data->{'categoryname'}, $data->{'codedescription'},$data->{'categorytype'} );
		$sth->finish();		
	}
	else {
		# modifying
		my $sth = $dbh->prepare("UPDATE branchcategories SET categoryname=?,codedescription=?,categorytype=? WHERE categorycode=?");
		$sth->execute($data->{'categoryname'}, $data->{'codedescription'},$data->{'categorytype'},uc( $data->{'categorycode'} ) );
		$sth->finish();
	}
    _clear_bcat_cache();
    _clear_branches_cache();
}

=head2 DeleteBranchCategory

DeleteBranchCategory($categorycode);

=cut

sub DelBranchCategory {
    my ($categorycode) = @_;
    my $sth = C4::Context->dbh->do(
        'DELETE FROM branchcategories WHERE categorycode = ?', undef, $categorycode);
    _clear_branches_cache();
    _clear_bcat_cache();
}

=head2 CheckBranchCategorycode

$number_rows_affected = CheckBranchCategorycode($categorycode);

=cut

sub CheckBranchCategorycode {
    return scalar @{GetBranchesInCategory(shift)};
}

sub GetBranchCodeFromName {
    my $branchname = shift;
    my @branch = grep {$_->{branchname} eq $branchname} values %{GetBranches()};
    return (@branch) ? $branch[0]->{branchcode} : '';
}

# This searches the contents of branches.branchip for a match to parameter $ip.
# Note that this means the matched branch is not predictable if there are
# overlapping IP ranges!
# 
# Returns the branches.branchcode for the first match or undef if no match.
sub GetBranchByIp {
    my ($ip) = shift
               // $ENV{HTTP_X_FORWARDED_FOR}
               // $ENV{REMOTE_ADDR};

    my $collection = Net::CIDR::Compare->new();

    my $client_cidr = $collection->new_list();
    $collection->add_range($client_cidr, $ip, 0);
    
    foreach my $branch (values %{GetBranches()}) {
        my $library_cidr = $collection->new_list();
        map {$collection->add_range($library_cidr, $_, 0)} split(/\n/, $branch->{branchip});
        $collection->process_intersection();
        return $branch->{branchcode} if ($collection->get_next_intersection_range());
        $collection->remove_list($library_cidr);
    }

    return;
}

1;
__END__

=head1 AUTHOR

Koha Developement team <info@koha.org>

=cut
