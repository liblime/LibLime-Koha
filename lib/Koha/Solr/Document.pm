package Koha::Solr::Document;

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
use MooseX::Role::WithOverloading;
use Method::Signatures;
use WebService::Solr::Document;

use overload
    q{""} => \&WebService::Solr::Document::to_xml;

requires 'BUILD';

has 'wss_doc' => (
    is => 'ro',
    isa => 'WebService::Solr::Document',
    default => sub {WebService::Solr::Document->new},
    handles =>
        [qw( add_fields to_xml to_element field_names value_for values_for)],
    lazy => 1,
    );

has 'strategy' => (
    is => 'ro',
    does => 'Koha::Solr::IndexStrategy',
    required => 1,
    );

no Moose::Role;
1;
