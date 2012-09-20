package Koha::Format;

use Koha;
use Moose;
use Carp;

has 'labels' => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
    );

has 'label_map' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    );

has 'soft_fail' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    );

sub _build_labels {
    return [
        {code => 'book', description => 'Book', category => 'print'},
        {code => 'cassette', description => 'Cassette', category => 'audio'},
        {code => 'software', description => 'Software', category => 'computing'},
        {code => 'videocassette', description => 'Videocassette', category => 'video'},
        {code => 'digital-audio-player', description => 'Digital audio player', category => 'computing'},
        {code => 'website', description => 'Website or downloadable', category => 'computing'},
        {code => 'music', description => 'Music', category => 'audio'},
        {code => 'audiobook', description => 'Audiobook', category => 'audio'},
        {code => 'compact-disc', description => 'Compact disc', category => 'audio'},
        {code => 'large-print-book', description => 'Large print book', category => 'print'},
        {code => 'braille-book', description => 'Braille book', category => 'print'},
        {code => 'graphic-novel', description => 'Graphic novel', category => 'print'},
        {code => 'dvd', description => 'DVD', category => 'video'},
        {code => 'blu-ray', description => 'Blu-ray DVD', category => 'video'},
        {code => 'video-game', description => 'Video game', category => 'computing'},
        {code => '', description => 'Unspecified', category => ''},
        ];
}

sub _build_label_map {
    my $self = shift;
    return { map {$_->{code} => $_ } @{$self->labels} };
}

sub lookup {
    my ($self, $code) = @_;
    my $label = $self->label_map->{$code};
    croak "Unable to find format for code '$code'"
        unless $label || $self->soft_fail;
    $label //= $self->label_map->{''};
    return $label->{description};
}

sub all_descriptions {
    my $self = shift;
    return map {$_->{description}} @{$self->labels};
}

sub all_categories {
    my $self = shift;
    my %cats = map {$_->{category} => 1} @{$self->labels};
    my @cat_labels = sort keys %cats;
    return @cat_labels;
}

sub all_descriptions_by_category {
    my $self = shift;
    my %cats;
    for ( @{$self->labels} ) {
        my $cat = $_->{category};
        $cats{$cat} //= [];
        push $cats{$cat}, $_->{description};
    }
    return %cats;
}

1;
