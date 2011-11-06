package C4::View::Util;

use Modern::Perl;

use C4::Koha;
use C4::Branch;

sub SetSelectedInList {
    my ($list, $callback) = @_;

    map {$_->{selected} = 1 if $callback->($_)} @{$list};
            
    return;
};

sub BuildSearchDomainList {
    my ($specified_category) = @_;

    my $cats = C4::Branch::GetBranchCategories(undef, 'searchdomain');
    return if (scalar @{$cats} == 0);

    if (   !$specified_category
        && (my $opacconf = C4::Koha::GetOpacConfigByHostname(
                \&C4::Koha::CgiOrPlackHostnameFinder)))
    {
        $specified_category = $opacconf->{default_search_category};
    }
    SetSelectedInList($cats,
                      sub {my $a = shift; $a->{categorycode} ~~ $specified_category});

    return $cats;
};

1;
