#!/usr/bin/env perl


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

use CGI;
use strict;
use warnings;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use Koha;
use C4::Context;
use C4::Dates;
use C4::Form::AddItem;
use C4::Branch;
use C4::Koha;
use C4::ClassSource;
use C4::Reserves;
use C4::Session::Defaults::Items;

use MARC::File::XML;


my $input = new CGI;
my $dbh = C4::Context->dbh;
my $error        = $input->param('error');
my $biblionumber = $input->param('biblionumber');
my $itemnumber   = $input->param('itemnumber') || '';
my $op           = $input->param('op') || '';

$op = 'set_session_defaults' 	if ( $input->param('set_session_defaults') );
$op = 'clear_session_defaults' 	if ( $input->param('clear_session_defaults') );
$op = 'load_session_defaults' 	if ( $input->param('load_session_defaults') );
$op = 'delete_session_defaults' if ( $input->param('delete_session_defaults') );

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "cataloguing/additem.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {editcatalogue => '*'},
                 debug => 1,
                 });

## $restrict is for the concept of Work Libraries, wherein logged in
## librarian can only add/edit/delete/move items in their own work library(ies).
## sorry, I don't know how to get to the template params by method -hQ
my $restrict = C4::Context->preference('EditAllLibraries') ?undef:1;
$restrict = undef if $$template{param_map}{CAN_user_superlibrarian};

my $frameworkcode = &GetFrameworkCode($biblionumber);

my $today_iso = C4::Dates->today('iso');
$template->param(today_iso => $today_iso);

my $bctype = C4::Context->preference('autoBarcode') // '';
$bctype = '' if lc($bctype) eq 'off';
my $tagslib = &GetMarcStructure(1,$frameworkcode);
my $record = GetMarcBiblio($biblionumber);
my $oldrecord = TransformMarcToKoha($dbh,$record);
my $itemrecord;
my @omissions=();
my @today_fields=();
my $nextop="additem";
my @errors; # store errors found while checking data BEFORE saving item.

#-------------------------------------------------------------------------------
if ($op eq 'set_session_defaults') {
#-------------------------------------------------------------------------------
    my @tags      = $input->param( 'tag_0' );
    my @subfields = $input->param( 'subfield_0' );
    my @values    = $input->param( 'field_value_0' );

    my $item_defaults = new C4::Session::Defaults::Items();
                
    for( my $i = 0; $i < @values; $i++ ) {
      $item_defaults->set( field => $tags[$i], subfield => $subfields[$i], value => $values[$i] );
    }

    my $session_defaults_name = $input->param( 'session_defaults_name' );   
    $item_defaults->save( name => $session_defaults_name ) if ( $session_defaults_name );
#-------------------------------------------------------------------------------
} elsif ($op eq 'clear_session_defaults') {
#-------------------------------------------------------------------------------
    my $item_defaults = new C4::Session::Defaults::Items();
    $item_defaults->clear();
#-------------------------------------------------------------------------------
} elsif ($op eq 'load_session_defaults') {
#-------------------------------------------------------------------------------
    my $item_defaults = new C4::Session::Defaults::Items();
    my $session_defaults_to_load = $input->param( 'session_defaults_to_load' );
    $item_defaults->load( name => $session_defaults_to_load );    
#-------------------------------------------------------------------------------
} elsif ($op eq 'delete_session_defaults') {
#-------------------------------------------------------------------------------
    my $item_defaults = new C4::Session::Defaults::Items();
    $item_defaults->delete();
#-------------------------------------------------------------------------------
} elsif ($op eq "additem") {
#-------------------------------------------------------------------------------
    my ( $record, $barcode_not_unique ) = C4::Form::AddItem::get_item_record( $input, $frameworkcode, 0 );

    # type of add
    my $add_submit                 = $input->param('add_submit');
    my $add_duplicate_submit       = $input->param('add_duplicate_submit');
    my $add_multiple_copies_submit = $input->param('add_multiple_copies_submit');
    my $number_of_copies           = $input->param('number_of_copies');

    my $addedolditem = TransformMarcToKoha($dbh,$record);

    # If we have to add or add & duplicate, we add the item
    if ($add_submit || $add_duplicate_submit) {

   # note: if barcode validation is performed, this is already done/passed -hQ
	# check for item barcode # being unique
	my $exist_itemnumber = get_item_from_barcode($addedolditem->{'barcode'});
	push @errors,"barcode_not_unique" if($exist_itemnumber);
	# if barcode exists, don't create, but report The problem.
    unless ($exist_itemnumber) {
	    my ($oldbiblionumber,$oldbibnum,$oldbibitemnum) = AddItemFromMarc($record,$biblionumber);
        set_item_default_location($oldbibitemnum);
    }
	$nextop = "additem";
	if ($exist_itemnumber) {
	    $itemrecord = $record;
	}
    }

    # If we have to add & duplicate
    if ($add_duplicate_submit) {
        my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);
        if ($bctype) {
           # We try to get the next barcode
           use C4::Barcodes;
           my $barcodeobj = C4::Barcodes->new;
           my $barcodevalue = $barcodeobj->next_value($addedolditem->{'barcode'}) if $barcodeobj;
           if ($record->field($tagfield)->subfield($tagsubfield)) {
               # If we got the next codebar value, we put it in the record
               if ($barcodevalue) {
                   $record->field($tagfield)->update($tagsubfield => $barcodevalue);
               # If not, we delete the recently inserted barcode from the record (so the user can input a barcode himself)
               } else {
                   $record->field($tagfield)->update($tagsubfield => '');
               }
           }
        }
        else {
            $record->field($tagfield)->update($tagsubfield => '');
        }
        $itemrecord = $record;
    }

    # If we have to add multiple copies
    if ($add_multiple_copies_submit) {

        use C4::Barcodes;
        my $barcodeobj = C4::Barcodes->new;
        my $oldbarcode = $addedolditem->{'barcode'};
        my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);

	# If there is a barcode and we can't find him new values, we can't add multiple copies
        my $testbarcode = $barcodeobj->next_value($oldbarcode) if $barcodeobj;
	if ($oldbarcode && !$testbarcode) {

	    push @errors, "no_next_barcode";
	    $itemrecord = $record;

	} else {
	# We add each item

	    # For the first iteration
	    my $barcodevalue = $oldbarcode;
	    my $exist_itemnumber;


	    for (my $i = 0; $i < $number_of_copies;) {

		# If there is a barcode
		if ($barcodevalue) {

		    # Getting a new barcode (if it is not the first iteration or the barcode we tried already exists)
		    $barcodevalue = $barcodeobj->next_value($oldbarcode) if ($i > 0 || $exist_itemnumber);

		    # Putting it into the record
		    if ($barcodevalue) {
			$record->field($tagfield)->update($tagsubfield => $barcodevalue);
		    }

		    # Checking if the barcode already exists
		    $exist_itemnumber = C4::Form::AddItem::get_item_from_barcode($barcodevalue);
		}

		# Adding the item
        if (!$exist_itemnumber) {
            my ($oldbiblionumber,$oldbibnum,$oldbibitemnum) = AddItemFromMarc($record,$biblionumber);
            set_item_default_location($oldbibitemnum);

            # We count the item only if it was really added
            # That way, all items are added, even if there was some already existing barcodes
            # FIXME : Please note that there is a risk of infinite loop here if we never find a suitable barcode
            $i++;
        }

		# Preparing the next iteration
		$oldbarcode = $barcodevalue;
	    }
	    undef($itemrecord);
	}
    }

#-------------------------------------------------------------------------------
} elsif ($op eq "edititem") {
#-------------------------------------------------------------------------------
# retrieve item if exist => then, it's a modif
    $template->param('mv' => 1);
    $itemrecord = C4::Items::GetMarcItem($biblionumber,$itemnumber);
    $nextop = "saveitem";
#-------------------------------------------------------------------------------
} elsif ($op eq "addadditionalitem") {
#-------------------------------------------------------------------------------
# retrieve marc_value field of an existing record
    $itemrecord = C4::Items::GetMarcItem($biblionumber,$itemnumber);
    @omissions=('items.barcode','items.itemlost','items.damaged','items.wthdrawn','items.datelastborrowed',
                'items.notforloan','items.issues','items.renewals','items.reserves','items.restricted','items.onloan',
                'items.materials','items.copynumber');
    @today_fields=('items.datelastseen','items.dateaccessioned');
    $nextop="additem";
#-------------------------------------------------------------------------------
} elsif ($op eq "delitem") {
#-------------------------------------------------------------------------------
   my $delete_holds_permission = $template->param('CAN_user_reserveforothers_delete_holds');    

   ## check whether this is the last item in the bib record,
   ## if so, we can't delete it if there are holds on the bib.
   my $forceDelLastItem = $input->param('forceDelLastItem');
   my $continue = 1;
   if (C4::Items::isLastItemInBib($biblionumber,$itemnumber) && !$forceDelLastItem) {
      if (@{C4::Reserves::GetReservesFromBiblionumber($biblionumber) // []}) {
         push @errors, 'title_has_holds';
         $continue = 0;
      }
   }
   if ($continue) {
      # check that there is no issue on this item before deletion.
      my $sth=$dbh->prepare("select * from issues i where i.itemnumber=?");
      $sth->execute($itemnumber);
      my $onloan=$sth->fetchrow_hashref;
	   $sth->finish();
      $nextop="additem";
    
      if ($onloan){
         push @errors,"book_on_loan";
      } elsif ( GetReservesFromItemnumber( $itemnumber ) && !$delete_holds_permission ) {
         push @errors,"item_has_holds";
      } else {
		   # check it doesnt have a waiting reserve
		   $sth=$dbh->prepare("SELECT * FROM reserves WHERE found = 'W' AND itemnumber = ?");
		   $sth->execute($itemnumber);
		   my $reserve=$sth->fetchrow_hashref;
		   if ($reserve) {
		      push @errors, "item_waiting";
		   } else {
		      if ($forceDelLastItem) {
               if ($input->param('also_delete_holds')) {
                  CancelReserves({biblionumber=>$biblionumber});
               }
               else {
                  ## bib-level holds will magically reappear when an item is added
                  ## for this bib.  delete only item-level holds
                  CancelReserves({biblionumber=>$biblionumber,itemnumber=>$itemnumber});
               }
            }
            else {
               CancelReserves({ itemnumber => $itemnumber });
            }
			   &DelItem($dbh,$biblionumber,$itemnumber);
			   print $input->redirect("additem.pl?biblionumber=$biblionumber&frameworkcode=$frameworkcode");
			   exit;
	   	}
         push @errors,"book_reserved";
      }
   }
#-------------------------------------------------------------------------------
} elsif ($op eq "saveitem") {
#-------------------------------------------------------------------------------
    MoveItemToAnotherBiblio( $itemnumber, $biblionumber );
    if ($input->param('mv')) {
       C4::Reserves::fixPrioritiesOnItemMove($biblionumber);
    }
    if ($input->param('nukeHolds')) {
       my %p = ('itemnumber',$itemnumber);
       if ($input->param('onlyiteminbib')) { 
         $p{biblionumber} = $biblionumber;
         delete($p{itemnumber});
       }
       C4::Reserves::CancelReserves(\%p);
    }
    
    # rebuild
    my ( $itemtosave, $barcode_not_unique ) = C4::Form::AddItem::get_item_record( $input, $frameworkcode, 0, $itemnumber );
    if ( $barcode_not_unique ) {
        push @errors, 'barcode_not_unique';
    } else {
        my ($oldbiblionumber,$oldbibnum,$oldbibitemnum) = ModItemFromMarc($itemtosave,$biblionumber,$itemnumber);
        $itemnumber="";
    }
    $nextop="additem";
}

## Check to see if we are working on a new item for the record
$template->param( newitem => 1 ) if ( $op eq '' || $op eq "addadditionalitem" );

#
#-------------------------------------------------------------------------------
# build screen with existing items. and "new" one
#-------------------------------------------------------------------------------

# now, build existiing item list
my $temp = GetMarcWithItems( $biblionumber );
my @fields = $temp->fields();
#my @fields = $record->fields();
my %witness; #---- stores the list of subfields used at least once, with the "meaning" of the code
my @big_array;
#---- finds where items.itemnumber is stored
my (  $itemtagfield,   $itemtagsubfield) = &GetMarcFromKohaField("items.itemnumber", $frameworkcode);
my ($branchtagfield, $branchtagsubfield) = &GetMarcFromKohaField("items.homebranch", $frameworkcode);

foreach my $field (@fields) {
    next if ($field->tag()<10);
    my @subf = $field->subfields or (); # don't use ||, as that forces $field->subfelds to be interpreted in scalar context
    my %this_row;
# loop through each subfield
    for my $i (0..$#subf) {
       ## Suppress Perl warnings about uninitialized values.
       next unless defined $field->tag();
       next unless defined $tagslib->{$field->tag()};
       next unless defined $subf[$i][0];
       next unless defined $tagslib->{$field->tag()}->{$subf[$i][0]};
       $tagslib->{$field->tag()}->{$subf[$i][0]}->{tab} //= undef;
        next if ($tagslib->{$field->tag()}->{$subf[$i][0]}->{tab} ne 10 
                && ($field->tag() ne $itemtagfield 
                && $subf[$i][0]   ne $itemtagsubfield));

        $witness{$subf[$i][0]} = $tagslib->{$field->tag()}->{$subf[$i][0]}->{lib} if ($tagslib->{$field->tag()}->{$subf[$i][0]}->{tab}  eq 10);
      $tagslib->{$field->tag()} //= undef;
		if ($tagslib->{$field->tag()}->{$subf[$i][0]}->{tab}  eq 10) {
        	$this_row{$subf[$i][0]}=GetAuthorisedValueDesc( $field->tag(),
                        $subf[$i][0], $subf[$i][1], '', $tagslib) 
						|| $subf[$i][1];
		}

        if (($field->tag eq $branchtagfield) && ($subf[$i][0] eq $branchtagsubfield) && C4::Context->preference("IndependantBranches")) {
            #verifying rights
            my $userenv = C4::Context->userenv();
            unless (($userenv->{'flags'} == 1) or (($userenv->{'branch'} eq $subf[$i][1]))){
                    $this_row{'nomod'}=1;
            }
        }
        $this_row{itemnumber} = $subf[$i][1] if ($field->tag() eq $itemtagfield && $subf[$i][0] eq $itemtagsubfield);
    }
    if (%this_row) {
        push(@big_array, \%this_row);
    }
}
my ($holdingbrtagf,$holdingbrtagsubf) = &GetMarcFromKohaField("items.holdingbranch",$frameworkcode);
@big_array = sort {$a->{$holdingbrtagsubf} cmp $b->{$holdingbrtagsubf}} @big_array;

my @col_order = grep { exists $witness{$_} } ( C4::Context->preference("EditItemsColumnOrder") =~ /\w/g );
@col_order = sort keys %witness unless scalar @col_order;

# determing working library(ies) edit/delete for EditAllLibraries=0
my @worklibs;
if ($restrict) {
   my $usrCurrLib = C4::Context->userenv->{'branch'};
   $usrCurrLib = '' if $usrCurrLib eq 'NO_LIBRARY_SET';
   unless ($usrCurrLib) {
      # need to set the current library
      # warp speed out of here and come back later
      print $input->redirect('/cgi-bin/koha/circ/selectbranchprinter.pl');
      exit;
   }
   my $borrowernumber = C4::Members::GetBorrowerFromUser(
      C4::Context->userenv->{id}
   );
   @worklibs = C4::Members::GetWorkLibraries($borrowernumber);
}
$template->param(restrict=>$restrict);

# now, construct template !
# First, the existing items for display
my @item_value_loop;
my @header_value_loop;
my $branches = GetBranches;
my %br = (); # reverse branch hash
foreach(keys %$branches) {
   $br{$$branches{$_}{branchname}} = $_;
}
for my $row ( @big_array ) {
    my %row_data;
    my @item_fields = map +{ field => $_ || '' }, @$row{ @col_order };
    $row_data{item_value} = [ @item_fields ];
    $row_data{itemnumber} = $row->{itemnumber};
    $row_data{holds} = ( GetReservesFromItemnumber( $row->{itemnumber} ) );
    #reporting this_row values
    if ($restrict) { # cmp permanent location w/ worklibraries
        if ($br{$$row{a}} ~~ @worklibs) {
            $$row{nomod} = 0;
        }
        else {
            $$row{nomod} = 1;
        }
    }
    $row_data{'nomod'} = $row->{'nomod'} // 0;
    $row_data{a}     //= '';
    push(@item_value_loop,\%row_data);
}
# re-sort, editable items on top, then by permanent location
@item_value_loop = sort {
   $$a{nomod} <=> $$b{nomod}
|| $$a{a}     cmp $$b{a}
} @item_value_loop;

foreach my $subfield_code (@col_order) {
    my %header_value;
    $header_value{header_value} = $witness{$subfield_code};
    push(@header_value_loop, \%header_value);
}

my $item = C4::Form::AddItem::get_form_values( $tagslib, 0, {
                                                item => $itemrecord,
                                                biblio => $temp,
                                                wipe => \@omissions ,
                                                make_today => \@today_fields,   
                                                frameworkcode => $frameworkcode,
                                                worklibs => \@worklibs,
                                              });

if (@worklibs && $itemnumber) { # item ownership
   my $dbh = C4::Context->dbh;
   my $sth = $dbh->prepare("SELECT homebranch FROM items
   WHERE itemnumber = ?");
   $sth->execute($itemnumber);
   my($homebranch) = ($sth->fetchrow_array)[0];
   %br = ();
   foreach(@worklibs) { $br{$_} = 1 };
   if ($br{$homebranch}) {
      # do nothing
   }
   else {
      $template->param('notmyitem'=>1);
   }
}

## Move barcode field to the top of the list.
my $barcode_index = 0;
for my $i(0..$#{$item}) {
   if (($$item[$i]{tag} ~~ '952') && ($$item[$i]{subfield} ~~ 'p')) {
      $barcode_index = $i;
      last;   
   }
}
my @tmp = splice( @$item, $barcode_index, 1 );
my $t = $tmp[0];
my $barcode_id = $t->{id};
unshift( @$item, $t );
## pass DOM id of permanent location 952$a to template so
## that ajax call for barcode validation knows the branchcode.
## also pass for damaged status
my $i = 0;
foreach(@$item) {
   if ($$_{tag} eq '952') {
      if ($$_{subfield} eq 'a') {
         $template->param(branchcode_tag_id => $$_{id});
      }
      elsif ($$_{subfield} eq '4') {
         $template->param(damaged_tag_id => $$_{id});
         $template->param(AllowHoldsOnDamagedItems =>
            C4::Context->preference('AllowHoldsOnDamagedItems')
         );
      }
#      elsif (($$_{subfield} eq 'p') && !$bctype) {
#         $$_{marc_value} =~ s/(value\=\")([^\"]*)(\")/$1$3/s;
#      }
   }
   ## reset subfield's marc_lib
   $$_{marc_lib} =~ s/^(<span id\=\"error)(\d+)/$1$i/;
   $i++;
}

# what's the next op ? it's what we are not in : an add if we're editing, otherwise, and edit.
$template->param( title => $record->title() ) if ($record ne "-1");
$template->param(
    barcode_id   => $barcode_id,
    biblionumber => $biblionumber,
    title        => $oldrecord->{title},
    author       => $oldrecord->{author},
    item_loop        => \@item_value_loop,
    item_header_loop => \@header_value_loop,
    item             => $item,
    itemnumber       => $itemnumber,
    itemtagfield     => $itemtagfield,
    itemtagsubfield  => $itemtagsubfield,
    op      => $nextop,
    opisadd => ($nextop eq "saveitem") ? 0 : 1,
    C4::Search::enabled_staff_search_views,
);
foreach my $error (@errors) {
    $template->param($error => 1);
}

my $item_defaults = new C4::Session::Defaults::Items();
$template->param(
  item_defaults_using => $item_defaults->isUsingDefaults(),
  item_defaults_name => $item_defaults->name(),
  item_defaults_loop => $item_defaults->getSavedDefaultsList(),
  item_defaults_all_loop => $item_defaults->getSavedDefaultsList( getAll => 1 ),
);
$template->param( branchcode => C4::Context->userenv->{"branch"} ) unless ( C4::Context->userenv->{"branch"} eq 'NO_LIBRARY_SET' );

output_html_with_http_headers $input, $cookie, $template->output;

sub find_value {
    my ($tagfield,$insubfield,$record) = @_;
    my $result;
    my $indicator;
    foreach my $field ($record->field($tagfield)) {
        my @subfields = $field->subfields();
        foreach my $subfield (@subfields) {
            if (@$subfield[0] eq $insubfield) {
                $result .= @$subfield[1];
                $indicator = $field->indicator(1).$field->indicator(2);
            }
        }
    }
    return($indicator,$result);
}

sub get_item_from_barcode {
    my ($barcode)=@_;
    my $dbh=C4::Context->dbh;
    my $result;
    my $rq=$dbh->prepare("SELECT itemnumber from items where items.barcode=?");
    $rq->execute($barcode);
    ($result)=$rq->fetchrow;
    return($result);
}

sub set_item_default_location {
    my $itemnumber = shift;
    my $item = GetItem( $itemnumber );
    if ( C4::Context->preference('NewItemsDefaultLocation') ) {
        $item->{'permanent_location'} = $item->{'location'};
        $item->{'location'} = C4::Context->preference('NewItemsDefaultLocation');
        ModItem( $item, undef, $itemnumber);
    }
    else {
      $item->{'permanent_location'} = $item->{'location'} if !defined($item->{'permanent_location'});
      ModItem( $item, undef, $itemnumber);
    }
}

