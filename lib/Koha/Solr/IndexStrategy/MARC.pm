package Koha::Solr::IndexStrategy::MARC;

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
                my $fieldname = substr( $source, 0, 3 );
                my @subfieldnames = split '', substr( $source, 3 );
                my @subhandlers = map {
                    func( MARC::Record $record )
                        { return $record->subfield( $fieldname, $_ ) }
                } @subfieldnames;
                push @handlers, \@subhandlers;
            }

            when (/^\d\d\d$/) {
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
