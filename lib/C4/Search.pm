package C4::Search;

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
no warnings qw(uninitialized);
use C4::Context;
use C4::Biblio;    # GetMarcFromKohaField, GetBiblioData
use C4::Koha;
use C4::Tags qw();
use C4::Dates qw(format_date);
use C4::XSLT;
use C4::Branch qw(GetBranchName);
use URI::Escape;
use Try::Tiny;
use Koha::Solr::Service;
use Koha::Solr::Query;

# THIS MODULE IS DEPRECATED.
# ONLY THE FUNCTION searchResultDisplay
# is currently in use, and that should change soon.

# TODO: Rewrite this.
# Much of this should happen at index time.
sub searchResultDisplay {
    my ($doc, $opac) = @_;

    my $dbh = C4::Context->dbh;

    # FIXME - We build an authorised values hash here, using the default framework
    # though it is possible to have different authvals for different fws.
    my $shelflocations =
        GetKohaAuthorisedValues('items.location', '', undef, $opac);
    my $notforloan_authorised_value = GetAuthValCode('items.notforloan', '');
    my %itemtypes = %{C4::Koha::GetItemTypes()};
    my ($itemtag) = '952';

    my $itemcols = $dbh->selectcol_arrayref('SHOW COLUMNS FROM items');
    my %subfieldstosearch = map {
        my (undef, $subf) = GetMarcFromKohaField("items.$_", q{}); $_ => $subf
    } @{$itemcols};

    my $marcrecord = try {
        ($doc->{marcxml})
            ? MARC::Record->new_from_xml( $doc->{marcxml}, 'UTF-8' )
            : C4::Items::GetMarcWithItems( $doc->{biblionumber} );
    }
    catch {
        warn "could not read marcxml. $@";
        return;
    };
    return unless $marcrecord;

    if (my $limit_to_branches = C4::XSLT::LimitItemsToTheseBranches()) {
        my @deletable_items
            = grep {!($_->subfield('a') ~~ $limit_to_branches)} $marcrecord->field($itemtag);
        $marcrecord->delete_fields(@deletable_items);
    }

    my $oldbiblio = TransformMarcToKoha( $dbh, $marcrecord, '' );
    $oldbiblio->{subtitle} = C4::Biblio::get_koha_field_from_marc('bibliosubtitle', 'subtitle', $marcrecord, '');

    # add imageurl to itemtype if there is one
    $oldbiblio->{imageurl} = getitemtypeimagelocation( 'opac', $itemtypes{ $oldbiblio->{itemtype} }->{imageurl} );

    if (C4::Context->preference('AuthorisedValueImages')) {
        $oldbiblio->{authorised_value_images} = C4::Items::get_authorised_value_images(
            C4::Biblio::get_biblio_authorised_values($oldbiblio->{'biblionumber'}, $marcrecord)
            );
    }

    # Tags
    if (C4::Context->preference('TagsEnabled') and
        my $tag_quantity = C4::Context->preference('TagsShowOnList'))
    {
        $oldbiblio->{TagLoop} = C4::Tags::get_tags(
            {biblionumber=>$oldbiblio->{biblionumber},
             approved=>1, 'sort'=>'-weight', limit=>$tag_quantity });
    }

    # CoINs
    $oldbiblio->{coins} = try { GetCOinSBiblio($oldbiblio->{biblionumber}) };

    # Identifiers
    my $marcflavour = 'MARC21';
    $oldbiblio->{normalized_upc}  = GetNormalizedUPC(       $marcrecord,$marcflavour);
    $oldbiblio->{normalized_ean}  = GetNormalizedEAN(       $marcrecord,$marcflavour);
    $oldbiblio->{normalized_oclc} = GetNormalizedOCLCNumber($marcrecord,$marcflavour);
    $oldbiblio->{normalized_isbn} = GetNormalizedISBN(undef,$marcrecord,$marcflavour);
    $oldbiblio->{content_identifier_exists} = 1 if ($oldbiblio->{normalized_isbn} or $oldbiblio->{normalized_oclc} or $oldbiblio->{normalized_ean} or $oldbiblio->{normalized_upc});

    # edition information, if any
    $oldbiblio->{edition} = $oldbiblio->{editionstatement};
    $oldbiblio->{description} = $itemtypes{ $oldbiblio->{itemtype} }->{description};

    # Reserves status
    my %restype;
    my ($rescount,$reserves) = C4::Reserves::GetReservesFromBiblionumber($oldbiblio->{biblionumber});
    my $total_rescount = $rescount;
    foreach my $res (@$reserves) {
        if ($res->{itemnumber}) {
            $restype{$res->{itemnumber}} = "Attached";
            $rescount--;
        }
    }
    my ($suspended_rescount,$suspended_reserves) = C4::Reserves::GetSuspendedReservesFromBiblionumber($oldbiblio->{biblionumber});

    # Pull out the items fields
    my @fields = $marcrecord->field($itemtag);

    # Setting item statuses for display
    my @available_items_loop;
    my @onloan_items_loop;
    my @other_items_loop;

    my $available_items;
    my $onloan_items;
    my $other_items;

    my $ordered_count         = 0;
    my $available_count       = 0;
    my $onloan_count          = 0;
    my $longoverdue_count     = 0;
    my $other_count           = 0;
    my $wthdrawn_count        = 0;
    my $itemlost_count        = 0;
    my $itemsuppress_count    = 0;
    my $itembinding_count     = 0;
    my $itemdamaged_count     = 0;
    my $item_in_transit_count = 0;
    my $item_reserve_count    = 0;
    my $can_place_holds       = 0;
    my $items_count           = scalar(@fields);
    my $other_otherstatus = '';
    my $other_otherstatus_count = 0;

    # loop through every item
    my $itemcount = 0;
    foreach my $field (@fields) {
        $itemcount++;
        # populate the items hash

        my $item = {
            map {
                $_ => scalar $field->subfield($subfieldstosearch{$_})
            } keys %subfieldstosearch
        };

        my $hbranch     = C4::Context->preference('HomeOrHoldingBranch') eq 'homebranch' ? 'homebranch'    : 'holdingbranch';
        my $otherbranch = C4::Context->preference('HomeOrHoldingBranch') eq 'homebranch' ? 'holdingbranch' : 'homebranch';
        # set item's branch name, use HomeOrHoldingBranch syspref first, fall back to the other one
        $item->{branchname} =
            GetBranchName( $item->{$hbranch} )
            // GetBranchName( $item->{$otherbranch} );

        my @statusvalue = $dbh->selectrow_array(
            "SELECT description, holdsallowed
               FROM itemstatus
                 LEFT JOIN items ON itemstatus.statuscode=items.otherstatus
               WHERE itemnumber = ?",
            undef, $item->{itemnumber} );
        my ($otherstatus,$holdsallowed,$OPACstatusdisplay);
        if (@statusvalue) {
            ($otherstatus,$holdsallowed) = @statusvalue;
            $OPACstatusdisplay = 1;
        }
        else {
            $otherstatus = '';
            $holdsallowed = 1;
            $OPACstatusdisplay = 0;
        }

        my $prefix = $item->{$hbranch} . '--' . $item->{location} . $item->{itype} . $item->{itemcallnumber};
# For each grouping of items (onloan, available, unavailable), we build a key to store relevant info about that item
        if ( $item->{onloan} ) {
            $onloan_count++;
            my $key = $prefix . $item->{onloan} . $item->{barcode};
            $onloan_items->{$key}->{due_date} = format_date($item->{onloan});
            $onloan_items->{$key}->{count}++ if $item->{$hbranch};
            $onloan_items->{$key}->{branchname} = $item->{branchname};
            $onloan_items->{$key}->{location} = $shelflocations->{ $item->{location} };
            $onloan_items->{$key}->{itemcallnumber} = $item->{itemcallnumber};
            $onloan_items->{$key}->{imageurl} = getitemtypeimagelocation( 'opac', $itemtypes{ $item->{itype} }->{imageurl} );
            # if something's checked out and lost, mark it as 'long overdue'
            if ( $item->{itemlost} ) {
                $onloan_items->{$prefix}->{longoverdue}++;
                $longoverdue_count++;
            } else {	# can place holds as long as item isn't lost
                $can_place_holds = 1;
            }
        }

        # items not on loan, but still unavailable ( lost, withdrawn, damaged, suppressed )
        else {

            # item is on order
            if ( $item->{notforloan} == -1 ) {
                $ordered_count++;
            }

            # is item in transit?
            my $transfertwhen = '';
            my ($transfertfrom, $transfertto);

            unless ($item->{wthdrawn}
                    || $item->{itemlost}
                    || $item->{damaged}
                    || $item->{suppress}
                    || $item->{notforloan}
                    || ($holdsallowed == 0)
                    || $items_count > 20) {

                # A couple heuristics to limit how many times
                # we query the database for item transfer information, sacrificing
                # accuracy in some cases for speed;
                #
                # 1. don't query if item has one of the other statuses
                # 2. don't check transit status if the bib has
                #    more than 20 items
                #
                # FIXME: to avoid having the query the database like this, and to make
                #        the in transit status count as unavailable for search limiting,
                #        should map transit status to record indexed in Zebra.
                #
                ($transfertwhen, $transfertfrom, $transfertto) = C4::Circulation::GetTransfers($item->{itemnumber});
            }

            if ($restype{$item->{itemnumber}} ne "Attached") {
                $restype{$item->{itemnumber}} = ($itemcount <= $rescount) ? "Reserved" : '';
            }
            # item is withdrawn, lost or damaged
            if (   $item->{wthdrawn}
                || $item->{itemlost}
                || $item->{damaged}
                || $item->{suppress}
                || ($item->{notforloan} > 0)
                || ($holdsallowed == 0)
                || ($transfertwhen ne '')
                || ($restype{$item->{itemnumber}} eq "Attached")
                || ($restype{$item->{itemnumber}} eq "Reserved") )
            {
                $wthdrawn_count++        if $item->{wthdrawn};
                $itemlost_count++        if $item->{itemlost};
                $itemdamaged_count++     if $item->{damaged};
                $item_reserve_count++    if (($restype{$item->{itemnumber}} eq "Attached") || ($restype{$item->{itemnumber}} eq "Reserved"));
                if (($restype{$item->{itemnumber}} eq "Attached") || ($restype{$item->{itemnumber}} eq "Reserved")) {
                  $can_place_holds = 1;
                }
                $itemsuppress_count++    if $item->{suppress};
                $item_in_transit_count++ if $transfertwhen ne '';
                $item->{status} = $item->{wthdrawn} . "-" . $item->{itemlost} . "-" . $item->{damaged} . "-" . $item->{suppress} . "-" . $item->{notforloan};
                $other_count++;
                if ($holdsallowed == 0) {
                    $other_otherstatus_count++;
                    if ($other_otherstatus eq '') {
                        $other_otherstatus = $otherstatus;
                    }
                    else {
                        $other_otherstatus .= ', ' . $otherstatus;
                    }
                }

                my $key = $prefix . $item->{status};
                foreach (qw(wthdrawn itemlost damaged suppress branchname itemcallnumber)) {
                	$other_items->{$key}->{$_} = $item->{$_};
                }
                $other_items->{$key}->{intransit} = ($transfertwhen ne '') ? 1 : 0;
                $other_items->{$key}->{reserved} = (($restype{$item->{itemnumber}} eq "Attached") || ($restype{$item->{itemnumber}} eq "Reserved")) ? 1 : 0;
                $other_items->{$key}->{notforloan} = GetAuthorisedValueDesc('','',$item->{notforloan},'','',$notforloan_authorised_value,$opac) if $notforloan_authorised_value;
                $other_items->{$key}->{count}++ if $item->{$hbranch};
                $other_items->{$key}->{location} = $shelflocations->{ $item->{location} };
                $other_items->{$key}->{imageurl} = getitemtypeimagelocation( 'opac', $itemtypes{ $item->{itype} }->{imageurl} );
                $other_items->{$key}->{OPACstatusdisplay} = $OPACstatusdisplay;
                if (!defined($other_items->{$key}->{otherstatus})) {
                    $other_items->{$key}->{otherstatus} = $otherstatus;
                }
                else {
                    $other_items->{$key}->{otherstatus} .=', ' . $otherstatus;
                }
            }
            # item is available
            else {
                $can_place_holds = 1;
                $available_count++;
                $available_items->{$prefix}->{count}++ if $item->{$hbranch};
                foreach (qw(branchname itemcallnumber)) {
                	$available_items->{$prefix}->{$_} = $item->{$_};
                }
                $available_items->{$prefix}->{location} = $shelflocations->{ $item->{location} };
                $available_items->{$prefix}->{imageurl} = getitemtypeimagelocation( 'opac', $itemtypes{ $item->{itype} }->{imageurl} );
                $available_items->{$prefix}->{OPACstatusdisplay} = $OPACstatusdisplay;
                $available_items->{$prefix}->{otherstatus} = $otherstatus;
            }
        }
    }    # notforloan, item level and biblioitem level
    my ($availableitemscount, $onloanitemscount, $otheritemscount) = (0, 0, 0);
    my $maxitems = C4::Context->preference('maxItemsinSearchResults') // 1;
    for my $key ( sort keys %$onloan_items ) {
        ($onloanitemscount++ > $maxitems) and last;
        push @onloan_items_loop, $onloan_items->{$key};
    }
    for my $key ( sort keys %$other_items ) {
        ($otheritemscount++ > $maxitems) and last;
        push @other_items_loop, $other_items->{$key};
    }
    for my $key ( sort keys %$available_items ) {
        ($availableitemscount++ > $maxitems) and last;
        push @available_items_loop, $available_items->{$key}
    }

    # XSLT processing of some stuff for staff client
    if (C4::Context->preference('XSLTResultsDisplay') && !$opac) {
        $oldbiblio->{XSLTResultsRecord} = XSLTParse4Display(
            $oldbiblio->{biblionumber}, $marcrecord, 'Results', 'intranet');
    }
    # XSLT processing of some stuff for OPAC
    if (C4::Context->preference('OPACXSLTResultsDisplay') && $opac) {
        $oldbiblio->{XSLTResultsRecord} = XSLTParse4Display(
            $oldbiblio->{biblionumber}, $marcrecord, 'Results', 'opac');
    }

    # last check for norequest : if itemtype is notforloan, it can't be reserved either, whatever the items
    $can_place_holds = 0
        if $itemtypes{ $oldbiblio->{itemtype} }->{notforloan};
    $oldbiblio->{norequests} = 1 unless $can_place_holds;
    $oldbiblio->{itemsplural}          = 1 if $items_count > 1;
    $oldbiblio->{items_count}          = $items_count;
    $oldbiblio->{available_items_loop} = \@available_items_loop;
    $oldbiblio->{onloan_items_loop}    = \@onloan_items_loop;
    $oldbiblio->{other_items_loop}     = \@other_items_loop;
    $oldbiblio->{availablecount}       = $available_count;
    $oldbiblio->{onloancount}          = $onloan_count;
    $oldbiblio->{othercount}           = $other_count;
    $oldbiblio->{wthdrawncount}        = $wthdrawn_count;
    $oldbiblio->{itemlostcount}        = $itemlost_count;
    $oldbiblio->{damagedcount}         = $itemdamaged_count;
    $oldbiblio->{intransitcount}       = $item_in_transit_count;
    $oldbiblio->{orderedcount}         = $ordered_count;
    $oldbiblio->{reservecount}         = $item_reserve_count;
    $oldbiblio->{total_reservecount}   = $total_rescount;
    $oldbiblio->{active_reservecount}  = $total_rescount - $suspended_rescount;
    $oldbiblio->{other_otherstatus}    = $other_otherstatus;
    $oldbiblio->{other_otherstatuscount} = $other_otherstatus_count;

    return $oldbiblio;
}

=head2 enabled_staff_search_views

%hash = enabled_staff_search_views()

This function returns a hash that contains three flags obtained from the system
preferences, used to determine whether a particular staff search results view
is enabled.

=over 2

=item C<Output arg:>

    * $hash{can_view_MARC} is true only if the MARC view is enabled
    * $hash{can_view_ISBD} is true only if the ISBD view is enabled
    * $hash{can_view_labeledMARC} is true only if the Labeled MARC view is enabled

=item C<usage in the script:>

=back

$template->param ( C4::Search::enabled_staff_search_views );

=cut

sub enabled_staff_search_views {
    return (
        can_view_MARC => C4::Context->preference('viewMARC'),
        can_view_ISBD => C4::Context->preference('viewISBD'),
        can_view_labeledMARC => C4::Context->preference('viewLabeledMARC'),
	);
}


1;
