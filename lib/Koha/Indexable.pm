package Koha::Indexable;

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
use Koha::Solr::Service;
use Method::Signatures;

with 'Koha::DbRecord';

has 'changelog' => (
    is => 'ro',
    isa => 'Koha::Changelog',
    lazy_build => 1,
    );

requires qw( _build_changelog );

after 'save' => method {
    $self->changelog->update($self->id, 'update');
};

after 'delete' => method {
    $self->changelog->update($self->id, 'delete');
};

1;
