#!/usr/bin/env perl

use Koha;
use Koha::Solr::IndexStrategy::MARC;
use Koha::Solr::Document::MARC;

use Test::More;
use Method::Signatures;
use MARC::Record;
use MARC::File::XML;

my $fields_result = [
 [
  'title',
  'asdf Discovering enzymes / qwer'
 ],
 [
  'ln',
  'eng'
 ],
 [
  'author',
  'Dressler, David.'
 ],
 [
  'subject',
  'Enzymes.'
 ],
 [
  'subject',
  'Enzymealines.'
 ],
 [
  'item',
  'BARCODE:10173'
 ],
 [
  'item',
  'BARCODE:10174'
 ],
 [
  'item',
  'BARCODE:10175'
 ],
];

my $xml_result =
q{<doc>
  <field name="title">asdf Discovering enzymes / qwer</field>
  <field name="ln">eng</field>
  <field name="author">Dressler, David.</field>
  <field name="item">item1</field>
  <field name="item">item2</field>
  <field name="item">item3</field>
</doc>};

func concat(Str @strings) {
    return join ' ', @strings;
}

func asdf(Str @strings) {
    return join ' ', ('asdf', @strings, 'qwer');
}

func itemify(MARC::Field @fields) {
    return map { 'BARCODE:'.$_->subfield('p') } @fields;
}


my $rules_text = q{
title| 245ab|  +::concat +::asdf
ln| 008[35-37]
author| 100a
subject | 610at 650a 651a 652a 653a 654a 655a 656a 657a 690a
item | 952 | +::itemify
};

my $is = Koha::Solr::IndexStrategy::MARC->new(rules_text => $rules_text);

my $record = MARC::Record->new_from_xml(join '', <DATA>);

is_deeply $is->index_to_array($record), $fields_result;



my $doc_result = <<END;
<doc><field name="title">asdf Discovering enzymes / qwer</field><field name="ln">eng</field><field name="author">Dressler, David.</field><field name="subject">Enzymes.</field><field name="subject">Enzymealines.</field><field name="item">BARCODE:10173</field><field name="item">BARCODE:10174</field><field name="item">BARCODE:10175</field></doc>
END
chomp($doc_result);

my $doc = Koha::Solr::Document::MARC->new(record => $record, strategy => $is);
is "$doc", $doc_result;



done_testing;

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<collection
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
  xmlns="http://www.loc.gov/MARC21/slim">

<record>
  <leader>00799pam a2200241 a 4500</leader>
  <controlfield tag="001">   90044448</controlfield>
  <controlfield tag="005">19991006093053.0</controlfield>
  <controlfield tag="008">991006s1991    nyua     b    00110 eng  </controlfield>
  <datafield tag="010" ind1=" " ind2=" ">
    <subfield code="a">90044448</subfield>
  </datafield>
  <datafield tag="020" ind1=" " ind2=" ">
    <subfield code="a">0716750139 :</subfield>
    <subfield code="c">$29.95</subfield>
  </datafield>
  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">DLC</subfield>
    <subfield code="c">DLC</subfield>
    <subfield code="d">DLC</subfield>
  </datafield>
  <datafield tag="050" ind1="0" ind2="0">
    <subfield code="a">QP601</subfield>
    <subfield code="b">.D69 1990</subfield>
  </datafield>
  <datafield tag="082" ind1="0" ind2="0">
    <subfield code="a">574.19/25</subfield>
    <subfield code="2">20</subfield>
  </datafield>
  <datafield tag="100" ind1="1" ind2="0">
    <subfield code="a">Dressler, David.</subfield>
    <subfield code="d">1941-</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Discovering enzymes /</subfield>
    <subfield code="c">David Dressler, Huntington Potter.</subfield>
  </datafield>
  <datafield tag="260" ind1="0" ind2=" ">
    <subfield code="a">New York :</subfield>
    <subfield code="b">Scientific American Library :</subfield>
    <subfield code="b">Distributed by W.H. Freeman,</subfield>
    <subfield code="c">c1991.</subfield>
  </datafield>
  <datafield tag="300" ind1=" " ind2=" ">
    <subfield code="a">vi, 263 p. :</subfield>
    <subfield code="b">ill. (some col.) ;</subfield>
    <subfield code="c">24 cm.</subfield>
  </datafield>
  <datafield tag="500" ind1=" " ind2=" ">
    <subfield code="a">"This book is number 34 of a series"--T.p. verso.</subfield>
  </datafield>
  <datafield tag="504" ind1=" " ind2=" ">
    <subfield code="a">Includes bibliographical references (p. [257]) and index.</subfield>
  </datafield>
  <datafield tag="650" ind1=" " ind2="0">
    <subfield code="a">Enzymes.</subfield>
  </datafield>
  <datafield tag="651" ind1=" " ind2="0">
    <subfield code="a">Enzymealines.</subfield>
  </datafield>
  <datafield tag="700" ind1="1" ind2="0">
    <subfield code="a">Potter, Huntington.</subfield>
  </datafield>
  <datafield tag="961" ind1="w" ind2="l">
    <subfield code="t">11</subfield>
  </datafield>
  <datafield tag="999" ind1=" " ind2=" ">
    <subfield code="c">110</subfield>
    <subfield code="d">110</subfield>
  </datafield>
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="w">2010-07-26</subfield>
    <subfield code="p">10173</subfield>
    <subfield code="v">26.26</subfield>
    <subfield code="r">2010-07-26</subfield>
    <subfield code="4">0</subfield>
    <subfield code="0">0</subfield>
    <subfield code="6">574_190000000000000_DRE</subfield>
    <subfield code="9">128</subfield>
    <subfield code="b">BOYS</subfield>
    <subfield code="i">0</subfield>
    <subfield code="1">0</subfield>
    <subfield code="o">574.19 Dre</subfield>
    <subfield code="d">2010-07-26</subfield>
    <subfield code="8">NFBOOK</subfield>
    <subfield code="7">0</subfield>
    <subfield code="2">ddc</subfield>
    <subfield code="g">26.26</subfield>
    <subfield code="y">500-599</subfield>
    <subfield code="a">BOYS</subfield>
  </datafield>
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="w">2010-07-26</subfield>
    <subfield code="p">10174</subfield>
    <subfield code="v">26.26</subfield>
    <subfield code="r">2010-07-26</subfield>
    <subfield code="4">0</subfield>
    <subfield code="0">0</subfield>
    <subfield code="6">574_190000000000000_DRE</subfield>
    <subfield code="9">128</subfield>
    <subfield code="b">BOYS</subfield>
    <subfield code="i">0</subfield>
    <subfield code="1">0</subfield>
    <subfield code="o">574.19 Dre</subfield>
    <subfield code="d">2010-07-26</subfield>
    <subfield code="8">NFBOOK</subfield>
    <subfield code="7">0</subfield>
    <subfield code="2">ddc</subfield>
    <subfield code="g">26.26</subfield>
    <subfield code="y">500-599</subfield>
    <subfield code="a">BOYS</subfield>
  </datafield>
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="w">2010-07-26</subfield>
    <subfield code="p">10175</subfield>
    <subfield code="v">26.26</subfield>
    <subfield code="r">2010-07-26</subfield>
    <subfield code="4">0</subfield>
    <subfield code="0">0</subfield>
    <subfield code="6">574_190000000000000_DRE</subfield>
    <subfield code="9">128</subfield>
    <subfield code="b">GIRLS</subfield>
    <subfield code="i">0</subfield>
    <subfield code="1">0</subfield>
    <subfield code="o">574.19 Dre</subfield>
    <subfield code="d">2010-07-26</subfield>
    <subfield code="8">NFBOOK</subfield>
    <subfield code="7">0</subfield>
    <subfield code="2">ddc</subfield>
    <subfield code="g">26.26</subfield>
    <subfield code="y">500-599</subfield>
    <subfield code="a">GIRLS</subfield>
  </datafield>
</record>
</collection>
