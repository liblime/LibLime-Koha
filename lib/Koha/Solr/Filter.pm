package Koha::Solr::Filter;

use Koha;
use Method::Signatures;
use List::Util qw();
use List::MoreUtils qw(uniq);
use MARC::Record;
use MARC::Field;
use MARC::File::XML;

func first( @_ ) {
    return (List::Util::first {defined $_} @_) // ();
}

func unique( Str @strings ) {
    return uniq @_;
}

func concat( Str @strings ) {
    return join ' ', @strings;
}

func map_language( Str $ln ) {
    return $ln;
}

func emit_format( MARC::Record $record ) {
    return 'DUMMY_FORMAT';
}

func cat_alpha_subfields( MARC::Field @fields ) {
    my @values;
    for my $field (@fields) {
        my $value = join q{ }, map { $_->[1] }
            grep { $_->[0] =~ /[a-z]/i} $field->subfields;
        push @values, $value;
    }
    return @values;
}

func on_shelf_at( MARC::Field @f952s ) {
    return map { $_->subfield('b') }
        grep { ! $_->subfield('q') } @f952s;
}

func owned_by( MARC::Field @f952s ) {
    return map { $_->subfield('b') } @f952s;
}

func itemify( MARC::Field @f952s ) {
    my @values;
    for my $f952 (@f952s) {
        my $value = join q{ }, map {"$_->[0]:$_->[1]"} $f952->subfields();
        push @values, $value;
    }
    return @values;
}

func as_marcxml( MARC::Record $record ) {
    return $record->as_xml;
}

1;
