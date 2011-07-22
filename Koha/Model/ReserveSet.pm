package Koha::Model::ReserveSet;

use Koha;
use Koha::Schema::Reserve::Manager;
use Moose;

has 'reserves' => (
    is => 'rw',
    isa => 'ArrayRef[Koha::Model::Reserve]'
    );

has 'limits' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {{}},
    );

sub BUILD {
    my ($self) = @_;

    my @where;
    for my $l (qw(biblionumber borrowernumber branchcode)) {
        if (defined $self->limits->{$l}) {
            push @where, ($l => $self->limits->{$l});
        }
    }
    my @limits = (
        query => \@where,
        sort_by => $self->limits->{sort_by} // 'priority ASC',
        );
    if (defined $self->limits->{limit}) {
        push @limits, (
            limit => $self->limits->{limit},
            offset => $self->limits->{offset} // 0,
        );
    }
    my $raw_reserves = Koha::Schema::Reserve::Manager->get_reserves(@limits);

    my @cooked_reserves = map {Koha::Model::Reserve->new(db_obj => $_)} @$raw_reserves;
    $self->reserves(\@cooked_reserves);
}

__PACKAGE__->meta->make_immutable;

1;
