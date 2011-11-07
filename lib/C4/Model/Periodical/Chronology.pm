package C4::Model::Periodical::Chronology;

use strict;
use warnings;
use Carp;
use DateTime;

use base qw(DateTime::Format::Strptime);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $args = {@_};

    my $original_pattern = $args->{pattern};
    $args->{pattern} = '%Y'; #just set a legal pattern

    my $self = $class->SUPER::new(%$args);
    $self->{chronpattern} = $original_pattern;
    bless $self, $class;

    return $self;
}

sub parse_datetime {
    croak 'not implemented';
}

my %northern_seasons = (
    0 => 'Winter',
    1 => 'Spring',
    2 => 'Summer',
    3 => 'Fall',
    4 => 'Winter'
    );

my %southern_seasons = (
    0 => 'Summer',
    1 => 'Fall',
    2 => 'Winter',
    3 => 'Spring',
    4 => 'Summer'
    );

sub format_datetime {
    my ($self, $dt) = @_;

    my $offset = int(($dt->month) / 3);
    my $northern_season = $northern_seasons{$offset};
    my $southern_season = $southern_seasons{$offset};

    my $processed_format = $self->{chronpattern};
    $processed_format =~ s/%q/$northern_season/;
    $processed_format =~ s/%Q/$southern_season/;
    $self->pattern($processed_format);

    return $self->SUPER::format_datetime($dt);
}

1;
