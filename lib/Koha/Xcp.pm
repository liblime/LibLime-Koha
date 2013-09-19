package Koha::Xcp;

#
# Copyright 2013 LibLime
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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
