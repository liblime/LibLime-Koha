package Koha::Model::RdbModel;

use Koha;
use MooseX::Role::Parameterized;

parameter 'nohandle' => {
    is  => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub{[]},
};

role {
    my $p = shift;
    my %args = @_;

    my $class = $args{consumer}->{package};
    $class =~ s/Model/Schema/;

    eval "require $class";
    $class->import;

    my @default_handlers = (
            $class->meta->column_names,
            (map {$_->name} $class->meta->foreign_keys),
            qw(save load delete),
        );

    my @handlers = grep {!($_ ~~ @{$p->nohandle})} @default_handlers;

    has 'db_obj' => (
        is => 'rw',
        isa => $class,
        handles => \@handlers,
        default => sub {
            $class->new;
        },
        );

    sub BUILD {
        my $self = shift;
        my $args = shift;

        delete $args->{db_obj};
        map {$self->db_obj->$_($args->{$_})} keys %{$args};
    }

};

no Moose;

1;
