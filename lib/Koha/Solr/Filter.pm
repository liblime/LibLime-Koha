package Koha::Solr::Filter;

use Koha;
use List::Util qw();
use List::MoreUtils qw(uniq);
use MARC::Record;
use MARC::Field;
use MARC::File::XML;
use Locale::Language qw( code2language );
use C4::Heading::MARC21;
use C4::Koha;
use C4::Biblio;
use C4::Tags;
use Koha::Format;
use File::Slurp;
use JSON;
use Try::Tiny;
use Business::ISBN;
use Method::Signatures;


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
    my @codes;

    my $f007 = $record->field('007');
    my $f008 = $record->field('008');
    my $f007_str = ($f007) ? sprintf( "%-23s", $f007->data) : '';
    my $f008_str = ($f008) ? sprintf( "%-40s", $f008->data) : '';

    my $rtype = substr $record->leader, 6, 1;
    my $bib_level = substr $record->leader, 7, 1;
    my $l_format = substr $f007_str, 0, 2;

    push @codes, 'book' if ($rtype eq 'a' and $bib_level eq 'm');
    push @codes, 'cassette' if ($l_format eq 'ss');
    push @codes, 'software' if ($l_format eq 'co');
    push @codes, 'videocassette' if ($l_format eq 'vf');
    push @codes, 'digital-audio-player' if ($l_format eq 'sz');
    push @codes, 'website' if ($l_format eq 'cr');
    push @codes, 'music' if ($rtype eq 'j');
    push @codes, 'audiobook' if ($rtype eq 'i');
    push @codes, 'compact-disc' if ($l_format eq 'sd');

    if ($f008) {
        my $e_format = substr $f008_str, 26, 1;
        my $ff8_23 = substr $f008_str, 23, 1;
        my $g_format = substr $f008_str, 24, 3;

        push @codes, 'large-print-book' if ($ff8_23 eq 'd');
        push @codes, 'braille-book' if ($ff8_23 eq 'f');
        push @codes, 'graphic-novel' if ($g_format =~ /^6/);
    }

    if ($f007 && length $f007_str > 4) {
        my $v_format = substr $f007_str, 4, 1;
        my $dt_vis = substr $f007_str, 0, 1;

        push @codes, 'dvd' if ($dt_vis eq 'v' && $v_format eq 'v');
        push @codes, 'blu-ray' if ($dt_vis eq 'v' && $v_format eq 's');
    }

    if ($f007 && $f008) {
        my $dt_vis = substr $f007_str, 0, 1;
        my $e_format = substr $f008_str, 26, 1;
        push @codes, 'video-game' if ($dt_vis eq 'c' && $e_format eq 'g');
    }

    push @codes, '' unless @codes;

    my $f = Koha::Format->new;
    my @descriptions = map {$f->lookup($_)} @codes;

    return @descriptions;
}

func emit_content( MARC::Record $record ) {
    my $rtype = substr $record->leader, 6, 1;
    my $f008 = $record->field('008');
    my $f008_str = sprintf( "%-40s", ($f008) ? $f008->data : '');
    my $fic_bio = substr $f008_str, 33, 2;
    return unless $fic_bio;
    my $content = "$rtype$fic_bio";
    $content =~ s/ /#/g;
    return $content;
}

func emit_audience( MARC::Record $record ) {
    my $f008 = $record->field('008');
    return undef unless $f008 && length($f008->data)>22; ## no critic
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

func itemify( MARC::Field @f952s ) {
    # emit item records as json.
    my @values;
    for my $f952 (@f952s) {
        my $item = C4::Items::GetItem($f952->subfield('9'));
        push @values, encode_json($item);
        #my $value = join q{ }, map {"$_->[0]:$_->[1]"} $f952->subfields();
        #push @values, $value;
    }
    return @values;
}

func emit_authids( MARC::Record $record ) {
    return map { scalar $_->subfield('9') }
        grep { $_->subfield('9') }
        map { $record->field($_) }
        keys %{$C4::Heading::MARC21::bib_heading_fields};
}

func on_shelf_at( MARC::Field @f952s ) {
    return map { $_->subfield('b') }
        grep { ! $_->subfield('q') && ! $_->subfield('1') } @f952s; # i.e. not onloan and not itemlost.
}

func for_loan_at( MARC::Field @f952s ){
    return map { $_->subfield('b') }
        grep { ! $_->subfield('q') && ! $_->subfield('1') && ! $_->subfield('7') } @f952s; # ! onloan, ! itemlost, ! notforloan
}

func owned_by( MARC::Field @f952s ) {
    return map { $_->subfield('b') } @f952s;
}

func dne_to_zero( Str @strings ) {
    if(@strings){
        return @strings;
    } else {
        return 0;
    }
}
func min_or_zero( Str @strings ) {
    return List::Util::min(@strings) || 0;
}

func fullmarc( MARC::Record $record ) {
    #FIXME: Exclude some coded fields and private notes and such.
    my @values;
    for my $f ($record->fields()){
        next if($f->tag() < '010');
        for my $sf ($f->subfields()){
            push @values, $sf->[1];
        }
    }
    return @values;
}

func title_sort( MARC::Field $f ){
    my $nonfiling = $f->indicator(2);
    $nonfiling = 0 unless $nonfiling =~ /\d/;
    return substr($f->subfield('a'), $nonfiling);
}

func ccode_authval( Str @strings ){
    my $ccodes = C4::Koha::GetKohaAuthorisedValues('items.ccode','',undef,1);
    return map { $ccodes->{$_} } @strings;
}
func loc_authval( Str @strings ){
    my $locs = C4::Koha::GetKohaAuthorisedValues('items.loc','',undef,1);
    return map { $locs->{$_} } @strings;
}
func itemtype_display( Str @strings ){
    my $itemtypes = C4::Koha::GetItemTypes();
    return map { $itemtypes->{$_}->{'description'} } @strings;
}

func most_recent( Str @strings ){
    return List::Util::maxstr(@strings) // ();
}

func emit_tags( Str $biblionumber ){
    my $tags = C4::Tags::get_tags({biblionumber=>$biblionumber, approved=>1});
    return map( $_->{term}, @$tags);
}

func as_marcxml( MARC::Record $record ) {
    return $record->as_xml;
}

func clean_year( Str @strings ){
    s/\D//g for @strings;
    return @strings;
}

func emit_datecreated( Str $biblionumber ){
    my ($wtf, @bib) = C4::Biblio::GetBiblio($biblionumber);
    return $bib[0]->{datecreated} . "T00:00:00Z" ;
}

func emit_isbn( Str @isbns ) {
    my @nisbns;

    for (@isbns) {
        s/[^0-9\- xX].*//;
        my $isbn = Business::ISBN->new($_);
        next unless $isbn;

        try {
            push @nisbns, $isbn->as_isbn10->isbn;
        };
        try {
            push @nisbns, $isbn->as_isbn13->isbn;
        };
    }

    return @nisbns;
}

1;
