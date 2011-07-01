#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
#
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

use CGI;
use strict;
use warnings;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Context;
use C4::Dates;
use C4::Form::AddItem;
use C4::Branch;
use C4::Koha;
use C4::ClassSource;
use C4::Reserves;

use MARC::File::XML;

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
    if ( C4::Context->preference('NewItemsDefaultLocation') ) {
        my $item = GetItem( $itemnumber );
        $item->{'permanent_location'} = $item->{'location'};
        $item->{'location'} = C4::Context->preference('NewItemsDefaultLocation');
        ModItem( $item, undef, $itemnumber);
    }
}

my $input = new CGI;
my $dbh = C4::Context->dbh;
my $error        = $input->param('error');
my $biblionumber = $input->param('biblionumber');
my $itemnumber   = $input->param('itemnumber') || '';
my $op           = $input->param('op') || '';
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "cataloguing/additem.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {editcatalogue => '*'},
                 debug => 1,
                 });

my $frameworkcode = &GetFrameworkCode($biblionumber);

my $today_iso = C4::Dates->today('iso');
$template->param(today_iso => $today_iso);

my $tagslib = &GetMarcStructure(1,$frameworkcode);
my $record = GetMarcBiblio($biblionumber);
my $oldrecord = TransformMarcToKoha($dbh,$record);
my $itemrecord;
my @omissions=();
my @today_fields=();
my $nextop="additem";
my @errors; # store errors found while checking data BEFORE saving item.
#-------------------------------------------------------------------------------
if ($op eq "additem") {
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

        # We try to get the next barcode
        use C4::Barcodes;
        my $barcodeobj = C4::Barcodes->new;
        my $barcodevalue = $barcodeobj->next_value($addedolditem->{'barcode'}) if $barcodeobj;
        my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);
        if ($record->field($tagfield)->subfield($tagsubfield)) {
            # If we got the next codebar value, we put it in the record
            if ($barcodevalue) {
                $record->field($tagfield)->update($tagsubfield => $barcodevalue);
            # If not, we delete the recently inserted barcode from the record (so the user can input a barcode himself)
            } else {
                $record->field($tagfield)->update($tagsubfield => '');
            }
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
    # check that there is no issue on this item before deletion.
    my $sth=$dbh->prepare("select * from issues i where i.itemnumber=?");
    $sth->execute($itemnumber);
    my $onloan=$sth->fetchrow;
	$sth->finish();
    $nextop="additem";

    my $delete_holds_permission = $template->param('CAN_user_reserveforothers_delete_holds');    
    
    if ($onloan){
        push @errors,"book_on_loan";
    } elsif ( GetReservesFromItemnumber( $itemnumber ) && !$delete_holds_permission ) {
        push @errors,"item_has_holds";
    } else {
		# check it doesnt have a waiting reserve
		$sth=$dbh->prepare("SELECT * FROM reserves WHERE found = 'W' AND itemnumber = ?");
		$sth->execute($itemnumber);
		my $reserve=$sth->fetchrow;
		if ($reserve) {
		  push @errors, "item_waiting";
		} else {
		        CancelReserves({ itemnumber => $itemnumber });
			&DelItem($dbh,$biblionumber,$itemnumber);
			print $input->redirect("additem.pl?biblionumber=$biblionumber&frameworkcode=$frameworkcode");
			exit;
		}
        push @errors,"book_reserved";
    }
#-------------------------------------------------------------------------------
} elsif ($op eq "saveitem") {
#-------------------------------------------------------------------------------
    MoveItemToAnotherBiblio( $itemnumber, $biblionumber );
    
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
$template->param( newitem => 1 ) if ( $op eq '' );

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
        next if ($tagslib->{$field->tag()}->{$subf[$i][0]}->{tab} ne 10 
                && ($field->tag() ne $itemtagfield 
                && $subf[$i][0]   ne $itemtagsubfield));

        $witness{$subf[$i][0]} = $tagslib->{$field->tag()}->{$subf[$i][0]}->{lib} if ($tagslib->{$field->tag()}->{$subf[$i][0]}->{tab}  eq 10);
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

# now, construct template !
# First, the existing items for display
my @item_value_loop;
my @header_value_loop;
for my $row ( @big_array ) {
    my %row_data;
    my @item_fields = map +{ field => $_ || '' }, @$row{ sort keys(%witness) };
    $row_data{item_value} = [ @item_fields ];
    $row_data{itemnumber} = $row->{itemnumber};
    $row_data{holds} = ( GetReservesFromItemnumber( $row->{itemnumber} ) );
    #reporting this_row values
    $row_data{'nomod'} = $row->{'nomod'};
    push(@item_value_loop,\%row_data);
}
foreach my $subfield_code (sort keys(%witness)) {
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

                                              });

## Move barcode field to the top of the list.
my $barcode_index = 0;                                              
foreach my $i ( @$item ) {
  if ( $i->{'marc_lib'} =~ m/Barcode/ ) {
    last;
  } else {
    $barcode_index++;
  }
}
my @tmp = splice( @$item, $barcode_index, 1 );
my $t = $tmp[0];
my $barcode_id = $t->{id};
unshift( @$item, $t );
for my $i(0..$#{$item}) { # fix index of error field
   $$item[$i]{marc_lib} =~ s/^(<span id\=\"error)(\d+)/$1$i/;
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
output_html_with_http_headers $input, $cookie, $template->output;
