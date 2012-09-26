package C4::Koha;

# Copyright 2000-2002 Katipo Communications
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

use warnings;
use strict;
use Koha;
use Koha::Format;
use C4::Context;
use C4::Output;
use Storable qw(freeze thaw);
use Clone qw(clone);
use URI::Split qw(uri_split);
use List::Util qw(first);
use Business::ISBN;

use vars qw($VERSION @ISA @EXPORT $DEBUG);

BEGIN {
	$VERSION = 3.01;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&slashifyDate
		&DisplayISBN
		&subfield_is_koha_internal_p
		&GetPrinters &GetPrinter
		&GetItemTypes &getitemtypeinfo
		&GetCcodes
		&get_itemtypeinfos_of
		&getframeworks &getframeworkinfo
		&getauthtypes &getauthtype
		&getallthemes
		&displayServers
		&getnbpages
		&get_infos_of
		&get_notforloan_label_of
		&getitemtypeimagedir
		&getitemtypeimagesrc
		&getitemtypeimagelocation
		&GetAuthorisedValues
		&GetAuthorisedValueCategories
		&GetKohaAuthorisedValues
                &GetAuthorisedValue
		&GetAuthValCode
		&GetNormalizedUPC
		&GetNormalizedISBN
		&GetNormalizedEAN
		&GetNormalizedOCLCNumber
        &GetOtherItemStatus
        &GetMarcSubfieldStructure
        &GetTableDescription
		$DEBUG
	);
	$DEBUG = 0;

}

=head1 NAME

    C4::Koha - Perl Module containing convenience functions for Koha scripts

=head1 SYNOPSIS

  use C4::Koha;


=head1 DESCRIPTION

    Koha.pm provides many functions for Koha scripts.

=head1 FUNCTIONS

=cut

=head2 slashifyDate

  $slash_date = &slashifyDate($dash_date);

    Takes a string of the form "DD-MM-YYYY" (or anything separated by
    dashes), converts it to the form "YYYY/MM/DD", and returns the result.

=cut

sub slashifyDate {

    # accepts a date of the form xx-xx-xx[xx] and returns it in the
    # form xx/xx/xx[xx]
    my @dateOut = split( '-', shift );
    return ("$dateOut[2]/$dateOut[1]/$dateOut[0]");
}


=head2 DisplayISBN

    my $string = DisplayISBN( $isbn );

=cut

sub DisplayISBN {
    my ($isbn) = @_;
    if (length ($isbn)<13){
    my $seg1;
    if ( substr( $isbn, 0, 1 ) <= 7 ) {
        $seg1 = substr( $isbn, 0, 1 );
    }
    elsif ( substr( $isbn, 0, 2 ) <= 94 ) {
        $seg1 = substr( $isbn, 0, 2 );
    }
    elsif ( substr( $isbn, 0, 3 ) <= 995 ) {
        $seg1 = substr( $isbn, 0, 3 );
    }
    elsif ( substr( $isbn, 0, 4 ) <= 9989 ) {
        $seg1 = substr( $isbn, 0, 4 );
    }
    else {
        $seg1 = substr( $isbn, 0, 5 );
    }
    my $x = substr( $isbn, length($seg1) );
    my $seg2;
    if ( substr( $x, 0, 2 ) <= 19 ) {

        # if(sTmp2 < 10) sTmp2 = "0" sTmp2;
        $seg2 = substr( $x, 0, 2 );
    }
    elsif ( substr( $x, 0, 3 ) <= 699 ) {
        $seg2 = substr( $x, 0, 3 );
    }
    elsif ( substr( $x, 0, 4 ) <= 8399 ) {
        $seg2 = substr( $x, 0, 4 );
    }
    elsif ( substr( $x, 0, 5 ) <= 89999 ) {
        $seg2 = substr( $x, 0, 5 );
    }
    elsif ( substr( $x, 0, 6 ) <= 9499999 ) {
        $seg2 = substr( $x, 0, 6 );
    }
    else {
        $seg2 = substr( $x, 0, 7 );
    }
    my $seg3 = substr( $x, length($seg2) );
    $seg3 = substr( $seg3, 0, length($seg3) - 1 );
    my $seg4 = substr( $x, -1, 1 );
    return "$seg1-$seg2-$seg3-$seg4";
    } else {
      my $seg1;
      $seg1 = substr( $isbn, 0, 3 );
      my $seg2;
      if ( substr( $isbn, 3, 1 ) <= 7 ) {
          $seg2 = substr( $isbn, 3, 1 );
      }
      elsif ( substr( $isbn, 3, 2 ) <= 94 ) {
          $seg2 = substr( $isbn, 3, 2 );
      }
      elsif ( substr( $isbn, 3, 3 ) <= 995 ) {
          $seg2 = substr( $isbn, 3, 3 );
      }
      elsif ( substr( $isbn, 3, 4 ) <= 9989 ) {
          $seg2 = substr( $isbn, 3, 4 );
      }
      else {
          $seg2 = substr( $isbn, 3, 5 );
      }
      my $x = substr( $isbn, length($seg2) +3);
      my $seg3;
      if ( substr( $x, 0, 2 ) <= 19 ) {
  
          # if(sTmp2 < 10) sTmp2 = "0" sTmp2;
          $seg3 = substr( $x, 0, 2 );
      }
      elsif ( substr( $x, 0, 3 ) <= 699 ) {
          $seg3 = substr( $x, 0, 3 );
      }
      elsif ( substr( $x, 0, 4 ) <= 8399 ) {
          $seg3 = substr( $x, 0, 4 );
      }
      elsif ( substr( $x, 0, 5 ) <= 89999 ) {
          $seg3 = substr( $x, 0, 5 );
      }
      elsif ( substr( $x, 0, 6 ) <= 9499999 ) {
          $seg3 = substr( $x, 0, 6 );
      }
      else {
          $seg3 = substr( $x, 0, 7 );
      }
      my $seg4 = substr( $x, length($seg3) );
      $seg4 = substr( $seg4, 0, length($seg4) - 1 );
      my $seg5 = substr( $x, -1, 1 );
      return "$seg1-$seg2-$seg3-$seg4-$seg5";       
    }    
}

# FIXME.. this should be moved to a MARC-specific module
sub subfield_is_koha_internal_p ($) {
    my ($subfield) = @_;

    # We could match on 'lib' and 'tab' (and 'mandatory', & more to come!)
    # But real MARC subfields are always single-character
    # so it really is safer just to check the length

    return length $subfield != 1;
}

=head2 GetItemTypes

  $itemtypes = &GetItemTypes();

Returns information about existing itemtypes.

build a HTML select with the following code :

=head3 in PERL SCRIPT

    my $itemtypes = GetItemTypes;
    my @itemtypesloop;
    foreach my $thisitemtype (sort keys %$itemtypes) {
        my $selected = 1 if $thisitemtype eq $itemtype;
        my %row =(value => $thisitemtype,
                    selected => $selected,
                    description => $itemtypes->{$thisitemtype}->{'description'},
                );
        push @itemtypesloop, \%row;
    }
    $template->param(itemtypeloop => \@itemtypesloop);

=head3 in TEMPLATE

    <form action='<!-- TMPL_VAR name="script_name" -->' method=post>
        <select name="itemtype">
            <option value="">Default</option>
        <!-- TMPL_LOOP name="itemtypeloop" -->
            <option value="<!-- TMPL_VAR name="value" -->" <!-- TMPL_IF name="selected" -->selected<!-- /TMPL_IF -->><!-- TMPL_VAR name="description" --></option>
        <!-- /TMPL_LOOP -->
        </select>
        <input type=text name=searchfield value="<!-- TMPL_VAR name="searchfield" -->">
        <input type="submit" value="OK" class="button">
    </form>

=cut

sub _seed_item_types {
    return C4::Context->dbh->selectall_hashref(
        'SELECT * FROM itemtypes', ['itemtype']);
}

sub GetItemTypes {
    my $cache = C4::Context->getcache(__PACKAGE__,
                                      {driver => 'Memory',
                                       datastore => C4::Context->cachehash});
    return $cache->compute( q{item_types}, '5m', sub {_seed_item_types} );
}

sub get_itemtypeinfos_of {
    my @itemtypes = @_;

    my $placeholders = join( ', ', map { '?' } @itemtypes );
    my $query = <<"END_SQL";
SELECT itemtype,
       description,
       imageurl,
       notforloan
  FROM itemtypes
  WHERE itemtype IN ( $placeholders )
END_SQL

    return get_infos_of( $query, 'itemtype', undef, \@itemtypes );
}

=head2 getauthtypes

  $authtypes = &getauthtypes();

Returns information about existing authtypes.

build a HTML select with the following code :

=head3 in PERL SCRIPT

my $authtypes = getauthtypes;
my @authtypesloop;
foreach my $thisauthtype (keys %$authtypes) {
    my $selected = 1 if $thisauthtype eq $authtype;
    my %row =(value => $thisauthtype,
                selected => $selected,
                authtypetext => $authtypes->{$thisauthtype}->{'authtypetext'},
            );
    push @authtypesloop, \%row;
}
$template->param(itemtypeloop => \@itemtypesloop);

=head3 in TEMPLATE

<form action='<!-- TMPL_VAR name="script_name" -->' method=post>
    <select name="authtype">
    <!-- TMPL_LOOP name="authtypeloop" -->
        <option value="<!-- TMPL_VAR name="value" -->" <!-- TMPL_IF name="selected" -->selected<!-- /TMPL_IF -->><!-- TMPL_VAR name="authtypetext" --></option>
    <!-- /TMPL_LOOP -->
    </select>
    <input type=text name=searchfield value="<!-- TMPL_VAR name="searchfield" -->">
    <input type="submit" value="OK" class="button">
</form>


=cut

sub getauthtypes {

    # returns a reference to a hash of references to authtypes...
    my %authtypes;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select * from auth_types order by authtypetext");
    $sth->execute;
    while ( my $IT = $sth->fetchrow_hashref ) {
        $authtypes{ $IT->{'authtypecode'} } = $IT;
    }
    return ( \%authtypes );
}

sub getauthtype {
    my ($authtypecode) = @_;

    # returns a reference to a hash of references to authtypes...
    my %authtypes;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select * from auth_types where authtypecode=?");
    $sth->execute($authtypecode);
    my $res = $sth->fetchrow_hashref;
    return $res;
}

=head2 getframework

  $frameworks = &getframework();

Returns information about existing frameworks

build a HTML select with the following code :

=head3 in PERL SCRIPT

my $frameworks = frameworks();
my @frameworkloop;
foreach my $thisframework (keys %$frameworks) {
    my $selected = 1 if $thisframework eq $frameworkcode;
    my %row =(value => $thisframework,
                selected => $selected,
                description => $frameworks->{$thisframework}->{'frameworktext'},
            );
    push @frameworksloop, \%row;
}
$template->param(frameworkloop => \@frameworksloop);

=head3 in TEMPLATE

<form action='<!-- TMPL_VAR name="script_name" -->' method=post>
    <select name="frameworkcode">
        <option value="">Default</option>
    <!-- TMPL_LOOP name="frameworkloop" -->
        <option value="<!-- TMPL_VAR name="value" -->" <!-- TMPL_IF name="selected" -->selected<!-- /TMPL_IF -->><!-- TMPL_VAR name="frameworktext" --></option>
    <!-- /TMPL_LOOP -->
    </select>
    <input type=text name=searchfield value="<!-- TMPL_VAR name="searchfield" -->">
    <input type="submit" value="OK" class="button">
</form>


=cut

sub getframeworks {

    # returns a reference to a hash of references to branches...
    my %itemtypes;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select * from biblio_framework");
    $sth->execute;
    while ( my $IT = $sth->fetchrow_hashref ) {
        $itemtypes{ $IT->{'frameworkcode'} } = $IT;
    }
    return ( \%itemtypes );
}

=head2 getframeworkinfo

  $frameworkinfo = &getframeworkinfo($frameworkcode);

Returns information about an frameworkcode.

=cut

sub getframeworkinfo {
    my ($frameworkcode) = @_;
    my $dbh             = C4::Context->dbh;
    my $sth             =
      $dbh->prepare("select * from biblio_framework where frameworkcode=?");
    $sth->execute($frameworkcode);
    my $res = $sth->fetchrow_hashref;
    return $res;
}

=head2 getitemtypeinfo

  $itemtype = &getitemtype($itemtype);

Returns information about an itemtype.

=cut

sub getitemtypeinfo {
    my ($itemtype) = @_;
    my $dbh        = C4::Context->dbh;
    my $sth        = $dbh->prepare("select * from itemtypes where itemtype=?");
    $sth->execute($itemtype);
    my $res = $sth->fetchrow_hashref;

    $res->{imageurl} = getitemtypeimagelocation( 'intranet', $res->{imageurl} );

    return $res;
}

=head2 getitemtypeimagedir

=over

=item 4

  my $directory = getitemtypeimagedir( 'opac' );

pass in 'opac' or 'intranet'. Defaults to 'opac'.

returns the full path to the appropriate directory containing images.

=back

=cut

sub getitemtypeimagedir {
	my $src = shift || 'opac';
	if ($src eq 'intranet') {
		return C4::Context->config('intrahtdocs') . '/' .C4::Context->preference('template') . '/img/itemtypeimg';
	} else {
		return C4::Context->config('opachtdocs') . '/' . C4::Context->preference('template') . '/itemtypeimg';
	}
}

sub getitemtypeimagesrc {
	my $src = shift || 'opac';
	if ($src eq 'intranet') {
		return '/intranet-tmpl' . '/' .	C4::Context->preference('template') . '/img/itemtypeimg';
	} else {
		return '/opac-tmpl' . '/' . C4::Context->preference('template') . '/itemtypeimg';
	}
}

sub getitemtypeimagelocation($$) {
	my ( $src, $image ) = @_;

	return '' if ( !$image );

	my $scheme = ( uri_split( $image ) )[0];

	return $image if ( $scheme );

	return getitemtypeimagesrc( $src ) . '/' . $image;
}

=head3 _getImagesFromDirectory

  Find all of the image files in a directory in the filesystem

  parameters:
    a directory name

  returns: a list of images in that directory.

  Notes: this does not traverse into subdirectories. See
      _getSubdirectoryNames for help with that.
    Images are assumed to be files with .gif or .png file extensions.
    The image names returned do not have the directory name on them.

=cut

sub _getImagesFromDirectory {
    my $directoryname = shift;
    return unless defined $directoryname;
    return unless -d $directoryname;

    if ( opendir ( my $dh, $directoryname ) ) {
        my @images = grep { /\.(gif|png)$/i } readdir( $dh );
        closedir $dh;
        return @images;
    } else {
        warn "unable to opendir $directoryname: $!";
        return;
    }
}

=head3 _getSubdirectoryNames

  Find all of the directories in a directory in the filesystem

  parameters:
    a directory name

  returns: a list of subdirectories in that directory.

  Notes: this does not traverse into subdirectories. Only the first
      level of subdirectories are returned.
    The directory names returned don't have the parent directory name
      on them.

=cut

sub _getSubdirectoryNames {
    my $directoryname = shift;
    return unless defined $directoryname;
    return unless -d $directoryname;

    if ( opendir ( my $dh, $directoryname ) ) {
        my @directories = grep { -d File::Spec->catfile( $directoryname, $_ ) && ! ( /^\./ ) } readdir( $dh );
        closedir $dh;
        return @directories;
    } else {
        warn "unable to opendir $directoryname: $!";
        return;
    }
}

=head3 getImageSets

  returns: a listref of hashrefs. Each hash represents another collection of images.
           { imagesetname => 'npl', # the name of the image set (npl is the original one)
             images => listref of image hashrefs
           }

    each image is represented by a hashref like this:
      { KohaImage     => 'npl/image.gif',
        StaffImageUrl => '/intranet-tmpl/prog/img/itemtypeimg/npl/image.gif',
        OpacImageURL  => '/opac-tmpl/prog/itemtypeimg/npl/image.gif'
        checked       => 0 or 1: was this the image passed to this method?
                         Note: I'd like to remove this somehow.
      }

=cut

sub getImageSets {
    my %params = @_;
    my $checked = $params{'checked'} || '';

    my $paths = { staff => { filesystem => getitemtypeimagedir('intranet'),
                             url        => getitemtypeimagesrc('intranet'),
                        },
                  opac => { filesystem => getitemtypeimagedir('opac'),
                             url       => getitemtypeimagesrc('opac'),
                        }
                  };

    my @imagesets = (); # list of hasrefs of image set data to pass to template
    my @subdirectories = _getSubdirectoryNames( $paths->{'staff'}{'filesystem'} );

    foreach my $imagesubdir ( @subdirectories ) {
        my @imagelist     = (); # hashrefs of image info
        my @imagenames = _getImagesFromDirectory( File::Spec->catfile( $paths->{'staff'}{'filesystem'}, $imagesubdir ) );
        foreach my $thisimage ( @imagenames ) {
            push( @imagelist,
                  { KohaImage     => "$imagesubdir/$thisimage",
                    StaffImageUrl => join( '/', $paths->{'staff'}{'url'}, $imagesubdir, $thisimage ),
                    OpacImageUrl  => join( '/', $paths->{'opac'}{'url'}, $imagesubdir, $thisimage ),
                    checked       => "$imagesubdir/$thisimage" eq $checked ? 1 : 0,
               }
             );
        }
        push @imagesets, { imagesetname => $imagesubdir,
                           images       => \@imagelist };
        
    }
    return \@imagesets;
}

=head2 GetPrinters

  $printers = &GetPrinters();
  @queues = keys %$printers;

Returns information about existing printer queues.

C<$printers> is a reference-to-hash whose keys are the print queues
defined in the printers table of the Koha database. The values are
references-to-hash, whose keys are the fields in the printers table.

=cut

sub GetPrinters {
    my %printers;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("select * from printers");
    $sth->execute;
    while ( my $printer = $sth->fetchrow_hashref ) {
        $printers{ $printer->{'printqueue'} } = $printer;
    }
    return ( \%printers );
}

=head2 GetPrinter

$printer = GetPrinter( $query, $printers );

=cut

sub GetPrinter ($$) {
    my ( $query, $printers ) = @_;    # get printer for this query from printers
    my $printer = $query->param('printer');
    my %cookie = $query->cookie('userenv');
    ($printer) || ( $printer = $cookie{'printer'} ) || ( $printer = '' );
    ( $printers->{$printer} ) || ( $printer = ( keys %$printers )[0] );
    return $printer;
}

=head2 getnbpages

Returns the number of pages to display in a pagination bar, given the number
of items and the number of items per page.

=cut

sub getnbpages {
    my ( $nb_items, $nb_items_per_page ) = @_;

    return int( ( $nb_items - 1 ) / $nb_items_per_page ) + 1;
}

=head2 getallthemes

  (@themes) = &getallthemes('opac');
  (@themes) = &getallthemes('intranet');

Returns an array of all available themes.

=cut

sub getallthemes {
    my $type = shift;
    my $htdocs;
    my @themes;
    if ( $type eq 'intranet' ) {
        $htdocs = C4::Context->config('intrahtdocs');
    }
    else {
        $htdocs = C4::Context->config('opachtdocs');
    }
    opendir D, "$htdocs";
    my @dirlist = readdir D;
    foreach my $directory (@dirlist) {
        -d "$htdocs/$directory/en" and push @themes, $directory;
    }
    return @themes;
}

=head2 get_infos_of

Return a href where a key is associated to a href. You give a query,
the name of the key among the fields returned by the query. If you
also give as third argument the name of the value, the function
returns a href of scalar. The optional 4th argument is an arrayref of
items passed to the C<execute()> call. It is designed to bind
parameters to any placeholders in your SQL.

  my $query = '
SELECT itemnumber,
       notforloan,
       barcode
  FROM items
';

  # generic href of any information on the item, href of href.
  my $iteminfos_of = get_infos_of($query, 'itemnumber');
  print $iteminfos_of->{$itemnumber}{barcode};

  # specific information, href of scalar
  my $barcode_of_item = get_infos_of($query, 'itemnumber', 'barcode');
  print $barcode_of_item->{$itemnumber};

=cut

sub get_infos_of {
    my ( $query, $key_name, $value_name, $bind_params ) = @_;

    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare($query);
    $sth->execute( @$bind_params );

    my %infos_of;
    while ( my $row = $sth->fetchrow_hashref ) {
        if ( defined $value_name ) {
            $infos_of{ $row->{$key_name} } = $row->{$value_name};
        }
        else {
            $infos_of{ $row->{$key_name} } = $row;
        }
    }
    $sth->finish;

    return \%infos_of;
}

=head2 get_notforloan_label_of

  my $notforloan_label_of = get_notforloan_label_of();

Each authorised value of notforloan (information available in items and
itemtypes) is link to a single label.

Returns a href where keys are authorised values and values are corresponding
labels.

  foreach my $authorised_value (keys %{$notforloan_label_of}) {
    printf(
        "authorised_value: %s => %s\n",
        $authorised_value,
        $notforloan_label_of->{$authorised_value}
    );
  }

=cut

sub get_notforloan_label_of {
    my ($statuscode) = C4::Context->dbh->selectrow_array( q{
        SELECT authorised_value
        FROM   marc_subfield_structure
        WHERE  kohafield = 'items.notforloan'
        LIMIT  0, 1
    });

    my %notforloan_label_of
        = map {$_->{authorised_value} => $_->{lib}} @{GetAuthorisedValues($statuscode)};

    return \%notforloan_label_of;
}

=head2 displayServers

=over 4

my $servers = displayServers();

my $servers = displayServers( $position );

my $servers = displayServers( $position, $type );

=back

displayServers returns a listref of hashrefs, each containing
information about available z3950 servers. Each hashref has a format
like:

    {
      'checked'    => 'checked',
      'encoding'   => 'MARC-8'
      'icon'       => undef,
      'id'         => 'LIBRARY OF CONGRESS',
      'label'      => '',
      'name'       => 'server',
      'opensearch' => '',
      'value'      => 'z3950.loc.gov:7090/',
      'zed'        => 1,
    },


=cut

sub displayServers {
    my ( $position, $type ) = @_;
    my $dbh = C4::Context->dbh;

    my $strsth = 'SELECT * FROM z3950servers';
    my @where_clauses;
    my @bind_params;

    if ($position) {
        push @bind_params,   $position;
        push @where_clauses, ' position = ? ';
    }

    if ($type) {
        push @bind_params,   $type;
        push @where_clauses, ' type = ? ';
    }

    # reassemble where clause from where clause pieces
    if (@where_clauses) {
        $strsth .= ' WHERE ' . join( ' AND ', @where_clauses );
    }

    my $rq = $dbh->prepare($strsth);
    $rq->execute(@bind_params);
    my @primaryserverloop;

    while ( my $data = $rq->fetchrow_hashref ) {
        push @primaryserverloop,
          { label    => $data->{description},
            id       => $data->{name},
            name     => "server",
            value    => $data->{host} . ":" . $data->{port} . "/" . $data->{database},
            encoding => ( $data->{encoding} ? $data->{encoding} : "iso-5426" ),
            checked  => "checked",
            icon     => $data->{icon},
            zed        => $data->{type} eq 'zed',
            opensearch => $data->{type} eq 'opensearch'
          };
    }
    return \@primaryserverloop;
}

=head2 GetAuthValCode

$authvalcode = GetAuthValCode($kohafield,$frameworkcode);

=cut

sub _seed_authvalcode_cache {
    my ($kohafield) = @_;
    return C4::Context->dbh->selectall_hashref( q{
        SELECT frameworkcode, authorised_value
        FROM marc_subfield_structure
        WHERE kohafield = ?
       }, 'frameworkcode', undef, $kohafield) // {};
}

sub GetAuthValCode {
    my ($kohafield, $fwcode) = @_;
    return if (!$kohafield);
    $fwcode //= q{};

    my $cache = C4::Context->getcache(__PACKAGE__,
                                      {driver => 'RawMemory',
                                       datastore => C4::Context->cachehash});
    my $codes = ($cache->compute(
                     qq{authvalcodes:$kohafield},
                     '5m',
                     sub {_seed_authvalcode_cache($kohafield)}));
    $codes->{$fwcode}{authorised_value};
}

=head2 GetAuthorisedValue

=cut

sub _seed_frozen_authvals_cache {
    return freeze(C4::Context->dbh->selectall_hashref('SELECT * FROM authorised_values', ['category', 'authorised_value']));
}

sub GetAuthorisedValuesTree {
    my $frozen_cache = C4::Context->getcache(__PACKAGE__,
                                             {driver => 'RawMemory',
                                              datastore => C4::Context->cachehash});
    thaw($frozen_cache->compute('frozen_authvals', '15s', \&_seed_frozen_authvals_cache));
}

sub _seed_thawed_authvals_cache {
    GetAuthorisedValuesTree();
}

sub GetAuthorisedValue {
    my ($category, $authorised_value) = @_;
    return undef if (!defined $category || !defined $authorised_value);
    my $thawed_cache = C4::Context->getcache(__PACKAGE__,
                                             {driver => 'RawMemory',
                                              datastore => C4::Context->cachehash});
    my $authvals = $thawed_cache->compute('thawed_authvals', '15s', \&_seed_thawed_authvals_cache);
    return clone($authvals->{$category}{$authorised_value});
}

=head2 GetAuthorisedValues

$authvalues = GetAuthorisedValues([$category], [$selected]);

This function returns all authorised values from the'authosied_value' table in a reference to array of hashrefs.

C<$category> returns authorised values for just one category (optional).

=cut

sub GetAuthorisedValues {
    my ($category, $selected) = @_;
    my $authvals = GetAuthorisedValuesTree();
    my @vals
        = (defined $category)
        ? map {$_} values %{$authvals->{$category}}
        : map {values %{$_}} map {$_} values %{$authvals};

    return \@vals if !defined $selected;

    for my $val (@vals) {
        if ($val->{authorised_value} eq $selected) {
            $val->{selected} = 1;
        }
    }

    return \@vals;
}

=head2 GetAuthorisedValueCategories

$auth_categories = GetAuthorisedValueCategories();

Return an arrayref of all of the available authorised
value categories.

=cut

sub GetAuthorisedValueCategories {
    return C4::Context->dbh->selectcol_arrayref(
        'SELECT DISTINCT category FROM authorised_values ORDER BY category');
}

sub GetCcodes {
    my $ccodes = GetAuthorisedValues('CCODE');
    return (scalar @$ccodes, @$ccodes);
}

=head2 GetKohaAuthorisedValues
	
	Takes $kohafield, $fwcode as parameters.
	Returns hashref of Code => description
	Returns undef 
	  if no authorised value category is defined for the kohafield.

=cut

sub GetKohaAuthorisedValues {
  my ($kohafield, $fwcode, undef, $opac) = @_;
  $fwcode //= '';

  my $avcode = GetAuthValCode($kohafield, $fwcode);
  return if !defined $avcode;

  my %values
      = map {$_->{authorised_value} => (($opac && $_->{opaclib}) ? $_->{opaclib} : $_->{lib})} @{GetAuthorisedValues($avcode)};

  return \%values;
}

=head2 display_marc_indicators

=over 4

# field is a MARC::Field object
my $display_form = C4::Koha::display_marc_indicators($field);

=back

Generate a display form of the indicators of a variable
MARC field, replacing any blanks with '#'.

=cut

sub display_marc_indicators {
    my $field = shift;
    my $indicators = '';
    if ($field->tag() >= 10) {
        $indicators = $field->indicator(1) . $field->indicator(2);
        $indicators =~ s/ /#/g;
    }
    return $indicators;
}

sub GetNormalizedUPC {
 my ($record,$marcflavour) = @_;
    my (@fields,$upc);

    if ($marcflavour eq 'MARC21') {
        @fields = $record->field('024');
        foreach my $field (@fields) {
            my $indicator = $field->indicator(1);
            my $upc = _normalize_match_point($field->subfield('a'));
            if ($indicator == 1 and $upc ne '') {
                return $upc;
            }
        }
    }
    else { # assume unimarc if not marc21
        @fields = $record->field('072');
        foreach my $field (@fields) {
            my $upc = _normalize_match_point($field->subfield('a'));
            if ($upc ne '') {
                return $upc;
            }
        }
    }
}

# Normalizes and returns the first valid ISBN found in the record
sub GetNormalizedISBN {
    my ($isbn,$record,$marcflavour) = @_;
    my @fields;
    if ($isbn) {
        return _isbn_cleanup($isbn);
    }
    return undef unless $record;

    if ($marcflavour eq 'MARC21') {
        @fields = $record->field('020');
        foreach my $field (@fields) {
            $isbn = $field->subfield('a');
            if ($isbn) {
                return _isbn_cleanup($isbn);
            } else {
                return undef;
            }
        }
    }
    else { # assume unimarc if not marc21
        @fields = $record->field('010');
        foreach my $field (@fields) {
            my $isbn = $field->subfield('a');
            if ($isbn) {
                return _isbn_cleanup($isbn);
            } else {
                return undef;
            }
        }
    }

}

sub GetNormalizedEAN {
    my ($record,$marcflavour) = @_;
    my (@fields,$ean);

    if ($marcflavour eq 'MARC21') {
        @fields = $record->field('024');
        foreach my $field (@fields) {
            my $indicator = $field->indicator(1);
            $ean = _normalize_match_point($field->subfield('a'));
            if ($indicator == 3 and $ean ne '') {
                return $ean;
            }
        }
    }
    else { # assume unimarc if not marc21
        @fields = $record->field('073');
        foreach my $field (@fields) {
            $ean = _normalize_match_point($field->subfield('a'));
            if ($ean ne '') {
                return $ean;
            }
        }
    }
}
sub GetNormalizedOCLCNumber {
    my ($record,$marcflavour) = @_;
    my (@fields,$oclc);

    if ($marcflavour eq 'MARC21') {
        @fields = $record->field('035');
        foreach my $field (@fields) {
            $oclc = $field->subfield('a') // '';
            if ($oclc =~ /OCoLC/) {
                $oclc =~ s/\(OCoLC\)//;
                return $oclc;
            } else {
                return undef;
            }
        }
    }
    else { # TODO: add UNIMARC fields
    }
}

=head2 GetOtherItemStatus

$statusvalues = GetOtherItemStatus($selected);

This function returns all of the item status values from the'itemstatus' table
in a reference to array of hashrefs.

=cut

sub GetOtherItemStatus {
    my $selected = shift;
    
    my $statuses
        = C4::Context->dbh->selectall_arrayref('SELECT * FROM itemstatus ORDER BY description', {Slice => {}});
    unshift @$statuses, {statuscode => '', description => ''}; #some callers expect an initial empty record
    return $statuses if !defined $selected;

    for my $status (@$statuses) {
        if ($selected eq $status->{statuscode}) {
            $status->{selected} = 1;
        }
    }
    return $statuses;
}

=head2 GetMarcSubfieldStructure

  @subfields = GetMarcSubfieldStructure( [ $kohafield[, $frameworkcode[, $exceptions_arrayref ] ] ] );
  
=cut

sub GetMarcSubfieldStructure {
  my ( $kohafield, $frameworkcode, $exceptions ) = @_;
  $kohafield .= '%';
  
  my $exceptions_sql;
  if ( $exceptions ) {
    foreach my $e ( @$exceptions ) {
      $e = "'$e'";
    }
    $exceptions_sql = join( ',', @$exceptions );
  }
  
  my $dbh = C4::Context->dbh;
  my $sql = "SELECT * FROM marc_subfield_structure WHERE kohafield LIKE ? AND frameworkcode LIKE '$frameworkcode' ";
  $sql .= " AND kohafield NOT IN ( $exceptions_sql ) " if ( $exceptions );
  $sql .= " ORDER BY tagfield, tagsubfield ";
  my $sth = $dbh->prepare( $sql );
  $sth->execute( $kohafield );

  my @results;
  while ( my $row = $sth->fetchrow_hashref() ) {
    push( @results, $row );
  }
  
  return @results;
}

=head2 GetTableDescription

my $table = GetTableDescription({ table => $table_name[, column => $column_name ] });

This function returns the results of the DESCRIBE command
on the given table.

=cut

sub GetTableDescription {
  my ( $params ) = @_;
  my $table = $params->{'table'};
  my $column = $params->{'column'};
  
  return unless ( $table );
  
  my @sql_params;
  
  my $sql = "DESCRIBE $table ";
  
  if ( $column ) {
    $sql .= "$column";
  }
  
  my $dbh = C4::Context->dbh;
  my $sth = $dbh->prepare( $sql );
  $sth->execute( @sql_params );  

  my $description = $sth->fetchall_arrayref({});
  return $description;
}

sub _normalize_match_point {
    my $match_point = shift;
    (my $normalized_match_point) = $match_point =~ /([\d-]*[X]*)/;
    $normalized_match_point =~ s/-//g;

    return $normalized_match_point;
}

sub _isbn_cleanup {
    my $isbn = Business::ISBN->new($_[0]);
    if ($isbn) {
        $isbn = $isbn->as_isbn10 if $isbn->type ~~ 'ISBN13';
        if (defined $isbn) {
            return $isbn->as_string([]);
        }
    }
    return;
}

sub CgiOrPlackHostnameFinder {
    my $env = shift || \%ENV;

    my $hostname
        =  $env->{HTTP_X_FORWARDED_HOST}
        // $env->{HTTP_X_FORWARDED_SERVER}
        // $env->{HTTP_HOST}
        // $env->{SERVER_NAME}
        // 'koha-opac.default';
    $hostname = (split qr{,}, $hostname)[0];
    $hostname =~ s/:.*//;
    return $hostname;
}

sub GetOpacConfigByHostname {
    my $coderef = shift;
    my $opacconfs = C4::Context->opachosts('opac');
    return {} if !defined $opacconfs;

    my $hostname = ($coderef) ? $coderef->() : '*';
    my $opacconf;
    while ($hostname) {
        $opacconf = first {$_->{hostname} ~~ $hostname} @{$opacconfs};
        last if $opacconf or $hostname eq '*';

        $hostname =~ s/^\*\.//;
        my @nameparts = split qr{\.}, $hostname;
        shift @nameparts;
        $hostname = join '.', ('*', @nameparts);
    }

    return $opacconf // {};
}

=head2 @filterloop = GetOpacSearchFilters

=over 4

Returns an array of hashes with keys 'label', 'value'
suitable for building an html option element in templates.

=back

=cut

sub GetOpacSearchFilters {
    # TODO: If C4::Context::preference could handle extended data types,
    # we could cache the results of this function in the sysprefs cache itself.
    my $filter_string = C4::Context->preference('OPACQuickSearchFilter');
    $filter_string =~ s/[\n\s]+$//;
    return undef
        unless $filter_string;

    my @filters = split(/\n+/, $filter_string);
    my $any_string = "Any format";

    if ( @filters == 1 ) {
        if($filters[0] =~ /^i(tem)?type/){
            my $itemtypes = GetItemTypes();
            @filters =  map({label => $itemtypes->{$_}->{'description'}, value => "itemtype:$_"}, keys %$itemtypes);
            $any_string = "Any type";
            @filters = sort {$a->{label} cmp $b->{label}} @filters;
        }
        elsif ($filters[0] =~ /^ccode/) {
            my $ccodes = GetAuthorisedValues('CCODE');
            @filters =  map({label => $_->{'opaclib'}||$_->{lib}||$_->{'authorised_value'}, value => "ccode:$_->{'authorised_value'}"}, @$ccodes);
            $any_string = "Any collection";
            @filters = sort {$a->{label} cmp $b->{label}} @filters;
        }
        elsif ($filters[0] =~ /^loc/) {
            my $ccodes = GetAuthorisedValues('LOC');
            @filters = sort map({label => $_->{'opaclib'}||$_->{lib}||$_->{'authorised_value'}, value => "shelfloc:$_->{'authorised_value'}"}, @$ccodes);
            $any_string = "Any location";
            @filters = sort {$a->{label} cmp $b->{label}} @filters;
        }
        elsif ($filters[0] =~ /^format/) {
            my %cats = Koha::Format->new->all_descriptions_by_category;
            delete $cats{''};
            @filters = map {
                    {separator => 1},
                    map { {label => $_, value => "format:&quot;$_&quot;"} } @$_
                } map { [values $cats{$_}] } qw(print video audio computing other);
        }
        else {
            return undef;
        }
    }
    else {
        # user-specified queries.
        my @select_html;
        for (@filters) {
            my ($label, $query) = split(/\|/, $_);
            $label =~ s/^\s+|\s+$//g;
            next unless $label;

            $query =~ s/^\s+|\s+$//g;
            $query =~ s/:\s+/:/g;

            push @select_html, { label => $label,
                                 value => $query,
                                 separator => ($label =~ /^---/) // undef };
        }
        @filters = @select_html;
    }

    if( !($filters[0]->{value} ~~ '') || $filters[0]->{separator} ) {
        #Fixme: translatable string?
        unshift(@filters,{label => $any_string, value => ''});
    }
    return (@filters) ? \@filters : undef;
}

1;

__END__

=head1 AUTHOR

Koha Team

=cut
