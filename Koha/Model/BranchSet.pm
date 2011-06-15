package Koha::Model::BranchSet;

use Koha;
use Koha::Schema::Branch::Manager;
use Moose;

has 'branches' => (
    is => 'rw',
    isa => 'ArrayRef[Koha::Model::Branch]'
    );

has 'limits' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {{}},
    );

sub BUILD {
    my ($self) = @_;

    my @where;
    for my $l (qw(branchcode branchname)) {
        if (defined $self->limits->{$l}) {
            push @where, ($l => $self->limits->{$l});
        }
    }
    my @limits = (
        query => \@where,
        sort_by => $self->limits->{sort_by} // 'branchname',
        );
    my $raw = Koha::Schema::Branch::Manager->get_branches(@limits);
    my @cooked = map {Koha::Model::Branch->new(db_obj => $_)} @$raw;
    $self->branches(\@cooked);
}

__PACKAGE__->meta->make_immutable;

1;
