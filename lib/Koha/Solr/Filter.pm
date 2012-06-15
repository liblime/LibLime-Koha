package Koha::Solr::Filter;

use Koha;
use Method::Signatures;
use List::Util qw();
use List::MoreUtils qw(uniq);
use MARC::Record;
use MARC::Field;
use MARC::File::XML;
use Locale::Language qw( code2language );
use C4::Heading::MARC21;

func emit_id( MARC::Record $record ) {
    my $leader = $record->leader;
    my $rtype = substr($leader, 6, 1);
    if ($rtype eq 'z') {
        my $id = $record->field('001')->data;
        return "auth_$id";
    }
    else {
        my $id = $record->subfield('999', 'c');
        return "bib_$id";
    }
}

func emit_auth_rtype( MARC::Record $record ) {
    return 'auth';
}

func emit_bib_rtype( MARC::Record $record ) {
    return 'bib';
}

func emit_authid( MARC::Record $record ) {
    return $record->field('001')->data;
}

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
    return code2language( $ln, 'alpha-3' );
}

func emit_format( MARC::Record $record ) {
    my @formats;

    my $rtype = substr $record->leader, 6, 1;
    my $bib_level = substr $record->leader, 7, 1;
    my $l_format = substr $record->leader, 0, 2;

    push @formats, 'book' if ($rtype eq 'a' and $bib_level eq 'm');
    push @formats, 'cassette' if ($l_format eq 'ss');
    push @formats, 'software' if ($l_format eq 'co');
    push @formats, 'videocassette' if ($l_format eq 'vf');
    push @formats, 'digital-audio-player' if ($l_format eq 'sz');
    push @formats, 'downloadable' if ($l_format eq 'cr');
    push @formats, 'music' if ($rtype eq 'j');
    push @formats, 'audiobook' if ($rtype eq 'i');
    push @formats, 'cd' if ($l_format eq 'sd');

    my $f007 = $record->field('007');
    my $f008 = $record->field('008');

    if ($f008) {
        my $e_format = substr $f008->data, 26, 1;
        my $ff8_23 = substr $f008->data, 23, 1;
        my $g_format = substr $f008->data, 24, 3;

        push @formats, 'large-print-book' if ($ff8_23 eq 'd');
        push @formats, 'braille-book' if ($ff8_23 eq 'f');
        push @formats, 'graphic-novel' if ($g_format eq '6');
    }

    if ($f007 && length $f007->data > 4) {
        my $v_format = substr $f007->data, 4, 1;
        my $dt_vis = substr $f007->data, 0, 1;

        push @formats, 'dvd' if ($dt_vis eq 'v' && $v_format eq 'v');
        push @formats, 'blue-ray' if ($dt_vis eq 'v' && $v_format eq 's');
    }

    if ($f007 && $f008) {
        my $dt_vis = substr $f007->data, 0, 1;
        my $e_format = substr $f008->data, 26, 1;
        push @formats, 'video-game' if ($dt_vis eq 'c' && $e_format eq 'g');
    }

    push @formats, 'unspecified' unless @formats;

    return @formats;
}

func emit_content( MARC::Record $record ) {
    my $rtype = substr $record->leader, 6, 1;
    my $f008 = $record->field('008');
    return unless $f008;
    my $fic = substr $f008->data, 33, 1;
    my $content = "$rtype$fic";
    $content =~ s/ /#/g;
    return $content;
}

func emit_audience( MARC::Record $record ) {
    my $f008 = $record->field('008');
    return undef unless $f008;
    my $aud = substr $f008->data, 22, 1;
    return $aud eq ' ' ? '#' : $aud;
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

func itemify( MARC::Field @f952s ) {
    my @values;
    for my $f952 (@f952s) {
        my $value = join q{ }, map {"$_->[0]:$_->[1]"} $f952->subfields();
        push @values, $value;
    }
    return @values;
}

func emit_authids( MARC::Record $record ) {
    return map { scalar $_->subfield('9') }
        grep { $_->subfield('9') }
        map { $record->field($_) }
        keys %{$C4::Heading::MARC21::bib_heading_fields};
}

func as_marcxml( MARC::Record $record ) {
    return $record->as_xml;
}

1;
