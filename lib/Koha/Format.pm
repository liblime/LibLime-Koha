package Koha::Format;

# Copyright 2012 PTFS/LibLime
#
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
        {code => 'digital-audio-player', description => 'Digital audio player', category => 'audio'},
        {code => 'website', description => 'Website or downloadable', category => 'computing'},
        {code => 'music', description => 'Music', category => 'other'},
        {code => 'printmusic', description => 'Printed Music', category => 'other'},
        {code => 'audiobook', description => 'Audiobook', category => 'other'},
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
