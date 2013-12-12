package Koha::Solr::Filter;

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
use List::Util qw();
use List::MoreUtils qw(uniq);
use MARC::Record;
use MARC::Field;
use MARC::File::XML;
use Locale::Language qw( code2language );
use C4::Koha;
use C4::Biblio;
use C4::Tags;
use C4::Reserves qw();
use C4::Circulation qw();
use Koha::Format;
use Koha::BareAuthority;
use Koha::HeadingMap;
use File::Slurp;
use JSON;
use Try::Tiny;
use Business::ISBN;
use Method::Signatures;


func emit_id( MARC::Record $record ) {
    my $leader = $record->leader;
    my $rtype = substr($leader, 6, 1);
    if ($rtype eq 'z') {
        my $id = $record->subfield('999', 'e');
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

func trim( Str @strings ) {
    return map { s/^\s+|\s+$//g; $_ } @strings;
}

func strip_nonalnum( Str @strings ) {
    return map { s/[^\w ]//g; $_ } @strings;
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
    push @codes, 'printmusic' if ($rtype eq 'c' or $rtype eq 'd');
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
        keys %{Koha::HeadingMap->bib_headings()};
}

func on_shelf_at( MARC::Field @f952s ) {
    return map { $_->subfield('b') }
        grep { ! defined C4::Reserves::GetReservesFromItemnumber($_->subfield('9')) }
        grep { ! C4::Circulation::GetTransfers($_->subfield('9')) }
        grep {   ! $_->subfield('q') && ! $_->subfield('1')
              && ! $_->subfield('7') && ! $_->subfield('4') }
        @f952s; # i.e. not onloan and not itemlost.
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

func all_items_lost( MARC::Field @f952s ){
    # if items, return true if all are lost.
    return (@f952s && (grep {$_->subfield('1')} @f952s) == @f952s) ? 'true' : 'false';
}

func fullmarc( MARC::Record $record ) {
    return map {$_->[1]}
        map {$_->subfields}
        grep {$_->tag ge '010' && $_->tag ne '952'}
        $record->fields;
}

func title_sort( MARC::Field $f ){
    my $title = $f->as_string('abcfghknps');
    my $nonfiling = $f->indicator(2);
    $nonfiling = 0 unless $nonfiling =~ /\d/;
    return substr($title, $nonfiling);
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
    s/(....).*/$1/ for @strings;
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

func emit_linked_rcns( MARC::Record $record ) {
    return map { scalar $_->subfield('0') }
        grep { $_->subfield('0') }
        map { $record->field($_) }
        keys %{Koha::HeadingMap->bib_headings()};
}

func emit_rcn( MARC::Record $record ) {
    return Koha::BareAuthority->new(marc => $record)->rcn;
}

func emit_coded_heading( MARC::Record $record ) {
    return Koha::BareAuthority->new(marc => $record)->csearch_string;
}

func auth_is_stub( MARC::Record $record ) {
    return Koha::BareAuthority->new(marc => $record)->is_stub // 0;
}

1;
