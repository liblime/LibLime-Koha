package MARC::Field::Normalize::NACO;

use strict;
use warnings;
use utf8;
use Unicode::Normalize qw(NFD);
use List::MoreUtils qw(natatime);
use MARC::Field;
use Method::Signatures;

use vars qw( @EXPORT_OK );
use Exporter 'import';
@EXPORT_OK = qw(
    naco_from_string naco_from_array
    naco_from_field naco_from_authority
);

func naco_from_string( Str $s, Bool :$keep_first_comma ) {
    # decompose and uppercase
    $s = uc( NFD($s) );

    # strip out combining diacritics
    $s =~ s/\p{M}//g;

    # transpose diagraphs and related characters
    $s =~ s/Æ/AE/g;
    $s =~ s/Œ/OE/g;
    $s =~ s/Ø|Ҩ/O/g;
    $s =~ s/Þ/TH/g;
    $s =~ s/Ð/D/g;
    $s =~ s/ß/SS/g;

    # transpose sub- and super-script with numerals
    $s =~ tr/⁰¹²³⁴⁵⁶⁷⁸⁹/0123456789/;
    $s =~ tr/₀₁₂₃₄₅₆₇₈₉/0123456789/;

    # delete or blank out punctuation
    $s =~ s/[!"()\-{}<>;:.?¿¡\/\\*\|%=±⁺⁻™℗©°^_`~]/ /g;
    $s =~ s/['\[\]ЪЬ·]//g;

    # blank out commas
    if ($keep_first_comma) {
        my $i = index $s, ',';
        $s =~ s/,/ /g;
        $s =~ s/^((?:.){$i})\s/$1,/;
    }
    else {
        $s =~ s/,/ /g;
    }

    # lastly, trim and deduplicate whitespace
    $s =~ s/\s\s+/ /g;
    $s =~ s/^\s+|\s+$//g;

    return $s;
}

func naco_from_array( ArrayRef $subfs ) {
    # Expects $subfs == [ 'a', 'Thurber, James', 'd', '1914-', ... ]
    my $itr = natatime 2, @$subfs;
    my $out = '';
    while (my ($subf, $val) = $itr->()) {
        my $norm = naco_from_string( $val, keep_first_comma => $subf eq 'a' );
        $out .= '$'. $subf . $norm;
    }
    return $out;
}

func naco_from_field( MARC::Field $f, :$subfields = 'a-z68') {
    my @flat = map {@$_} grep {$_->[0] =~ /[$subfields]/} $f->subfields;
    return naco_from_array( \@flat );
}

func naco_from_authority( MARC::Record $r ) {
    return naco_from_field( $r->field('1..') );
}

{
    no warnings qw(once);
    *MARC::Field::as_naco = \&naco_from_field;
}

1;
