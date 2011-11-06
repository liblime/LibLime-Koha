package Koha::Model::Reserve;

use Koha;
use C4::Reserves qw();
use Moose;

with 'Koha::Model::RdbModel' => {
    nohandle => [qw(save delete)],
};

sub save {
    my $self = shift;

    if (defined $self->reservenumber) {
        $self->db_obj->save();
        C4::Reserves::_NormalizePriorities($self->biblionumber);
    }
    else {
        my $reservenumber = C4::Reserves::AddReserve(
            $self->branchcode,
            $self->borrowernumber,
            $self->biblionumber,
            );
        $self->db_obj(Koha::Schema::Reserve->new(reservenumber => $reservenumber)->load);
    }

    return;
}

sub delete {
    my ($self) = @_;
    C4::Reserves::CancelReserve($self->reservenumber);
    return;
}

sub suspend {
    my ($self, $resume_date) = @_;
    C4::Reserves::SuspendReserve($self->reservenumber, $resume_date);
    $self->load;
}

sub unsuspend {
    my ($self) = @_;
    C4::Reserves::ResumeReserve($self->reservenumber);
    $self->load;
}

__PACKAGE__->meta->make_immutable;

1;
