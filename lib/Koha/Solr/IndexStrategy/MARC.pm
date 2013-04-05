package Koha::Solr::IndexStrategy::MARC;

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
use namespace::autoclean;
use Method::Signatures;
use Carp;
use MARC::Record;

with 'Koha::Solr::IndexStrategy';

method _build_source_handlers(Str @sources) {
    my @handlers;
    for my $source (@sources) {
        given ($source) {

            when (/^\d\d\d[a-z0-9]+$/) {
                # one or more subfields
                # Returns one element for each occurrence of a subfield in each field.
                my $fieldname = substr( $source, 0, 3 );
                my @subfieldnames = split '', substr( $source, 3 );
                my $handler = func( MARC::Record $record ){
                                my @data;
                                for my $f ($record->field($fieldname)){
                                    for my $sf (@subfieldnames){
                                        push @data, $f->subfield($sf);
                                     }
                                 }
                                 return @data;
                             };
                push @handlers, [$handler];
            }

            when (/^\d[\d.]{2}$/) {
                # a full MARC::Field object
                my $handler = func( MARC::Record $record) {
                    return $record->field($source);
                };
                push @handlers, [$handler];
            }

            when (/^(\d\d\d)\[(\d+)(?:-(\d+))?\]$/) {
                # contents of a position on a control field
                my $fieldnumber = $1;
                my $position    = $2;
                my $length      = ($3) ? $3 - $2 + 1 : 1;
                my $handler     = func( MARC::Record $record) {
                    my $field = $record->field($fieldnumber);
                        return unless $field;
                    unless ( $field->is_control_field ) {
                        carp "$1 is not a control field";
                        return;
                    }
                    my $data = $field->data;
                    # pad with spaces if request is longer than field.
                    my $requested_length = $position + $length;
                    $data = sprintf( "%-${requested_length}s", $data);
                    return substr( $data, $position, $length );
                };
                push @handlers, [$handler];
            }

            when (/^leader$/) {
                # pass in the leader contents
                my $handler = func( MARC::Record $record) {
                    return $record->leader;
                };
                push @handlers, [$handler];
            }

            when (/^record$/) {
                # pass in the full MARC::Record
                my $handler = func( MARC::Record $record) {
                    return $record;
                };
                push @handlers, [$handler];
            }

            when (/^string:.+$/) {
                # the term itself is the data to store.
                my $handler = func(MARC::Record $record){
                    return substr($source,7);
                };
                push @handlers, [$handler];
            
            }

            default {
                carp "Unknown source type '$source'";
            }
        }
    }

    return \@handlers;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
