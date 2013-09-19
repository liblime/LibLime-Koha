package Koha::DbRecord;

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

use Moose::Role;
use Koha;
use Method::Signatures;

has 'dbrec' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    );

has 'id' => (
    is => 'ro',
    isa => 'Int',
    lazy_build => 1,
    );

requires qw(_build_dbrec _build_id _insert _update _delete);

method save {
    ($self->has_id) ? $self->_update : $self->_insert;
    $self->clear_dbrec;
    return;
}

method delete {
    $self->_delete;
}

no Moose::Role;
1;
