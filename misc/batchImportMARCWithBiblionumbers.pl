#!/usr/bin/perl

# Copyright 2011 LibLime, a Division of PTFS, Inc.
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

# load records that already have biblionumber set into a koha system
# Written by TG on 10/04/2006
use strict;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/kohalib.pl" };
}

# Koha modules used

use C4::Context;
use C4::Biblio;
use MARC::Record;
use MARC::File::USMARC;
use MARC::File::XML;
use MARC::Batch;
use Time::HiRes qw(gettimeofday);
use Getopt::Long;
use IO::File;

my  $input_marc_file = '';
my ($version);
GetOptions(
    'file:s'    => \$input_marc_file,
    'h' => \$version,
);

if ($version || ($input_marc_file eq '')) {
	print <<EOF
If your ISO2709 file already has biblionumbers, you can use this script
to import the MARC into your database.
parameters :
\th : this version/help screen
\tfile /path/to/file/to/dump : the file to dump
SAMPLE : 
\t\$ export KOHA_CONF=/etc/koha.conf
\t\$ perl misc/marcimport_to_biblioitems.pl  -file /home/jmf/koha.mrc 
EOF
;#'
	die;
}
my $starttime = gettimeofday;
my $timeneeded;
my $dbh = C4::Context->dbh;

my $sth2=$dbh->prepare("update biblioitems  set marc=? where biblionumber=?");
my $fh = IO::File->new($input_marc_file); # don't let MARC::Batch open the file, as it applies the ':utf8' IO layer
my $batch = MARC::Batch->new( 'USMARC', $fh );
$batch->warnings_off();
$batch->strict_off();
my ($tagfield,$biblionumtagsubfield) = &GetMarcFromKohaField("biblio.biblionumber","");

my $i=0;
while ( my $record = $batch->next() ) {
	my $biblionumber=$record->field($tagfield)->subfield($biblionumtagsubfield);
	$i++;
	$sth2->execute($record->as_usmarc,$biblionumber) if $biblionumber;
	print "$biblionumber \n";
}

$timeneeded = gettimeofday - $starttime ;
print "$i records in $timeneeded s\n" ;

END;
# IS THIS SUPPOSED TO BE __END__ ??  If not, then what is it?  --JBA

sub search {
	my ($query)=@_;
	my $nquery="\ \@attr 1=1007  ".$query;
	my $oAuth=C4::Context->Zconn("biblioserver");
	if ($oAuth eq "error"){
		warn "Error/CONNECTING \n";
		return("error",undef);
	}
	my $oAResult;
	my $Anewq= new ZOOM::Query::PQF($nquery);
	eval {
	$oAResult= $oAuth->search_pqf($nquery) ; 
	};
	if($@){
		warn " /Cannot search:", $@->code()," /MSG:",$@->message(),"\n";
		return("error",undef);
	}
	my $authrecord;
	my $nbresults="0";
	$nbresults=$oAResult->size();
	if ($nbresults eq "1" ){
		my $rec=$oAResult->record(0);
		my $marcdata=$rec->raw();
		$authrecord = MARC::File::XML::decode($marcdata);
	}
	return ($authrecord,$nbresults);
}
