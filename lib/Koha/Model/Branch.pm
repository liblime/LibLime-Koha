package Koha::Model::Branch;

use Koha;
#use C4::Reserves qw();
use Moose;

with 'Koha::Model::RdbModel' => {
    nohandle => [qw(save)],
};

sub save {
    my $self = shift;
    if (defined $self->branchcode) {
        $self->db_obj->save();
    }
    else {
=foo
        my $reservenumber = C4::Reserves::AddReserve(
            $self->branchcode,
            $self->borrowernumber,
            $self->biblionumber,
            );
=cut

    }
    $self->db_obj(Koha::Schema::Branch->new(branchcode => $self->branchcode)->load);
}

__PACKAGE__->meta->make_immutable;

1;
