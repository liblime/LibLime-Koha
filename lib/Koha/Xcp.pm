package Koha::Xcp;

use Moose;
use Koha;

with 'Throwable';

around 'throw' => sub {
    my $orig = shift;
    my $self = shift;

    if (scalar @_ == 1) {
        unshift @_, 'message';
    }

    return $self->$orig( @_ );
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
