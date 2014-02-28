package C4::Form::AddItem;

# Copyright 2009 Jesse Weaver
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or ( at your option ) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

use CGI;
use Koha;
use C4::Context;
use C4::Debug;
use C4::Dates;
use C4::ClassSource;
use C4::Biblio;
use C4::Branch qw( GetBranchesLoop );
use C4::Koha qw( subfield_is_koha_internal_p ); # XXX subfield_is_koha_internal_p
use MARC::Record;
use MARC::File::XML;
use C4::Session::Defaults::Items;

=head1 NAME

C4::Form::AddItem - manage item values input form

=head1 SYNOPSIS

In script:

    use C4::Form::AddItem;
    C4::Form::AddItem::set_form_values( $existing_values, $template );

In HTML template:

    <!-- TMPL_INCLUDE NAME="item-fields.inc" -->

=head1 DESCRIPTION

This module manages the add item screen used in the import profiles
functionality of the stage-marc-import.pl tool. It is used both by the tool
itself and the service that returns existing item definitions for a profile.

=head1 FUNCTIONS

=head2 handle_form_action

    C4::Form::MessagingPreferences::handle_form_action( $input, { categorycode => 'CPL' }, $template );

Processes CGI parameters and updates the target patron or patron category's
preferences.

C<$input> is the CGI query object.

C<$target_params> is a hashref containing either a C<categorycode> key or a C<borrowernumber> key 
identifying the patron or patron category whose messaging preferences are to be updated.

C<$template> is the HTML::Template::Pro object for the response; this routine
adds a settings_updated template variable.

=cut

sub get_item_record {
    my ( $input, $frameworkcode, $item_index, $itemnumber ) = @_;
    my $dbh = C4::Context->dbh;
    my @tags      = $input->param( "tag_$item_index" );
    my @subfields = $input->param( "subfield_$item_index" );
    my @values    = $input->param( "field_value_$item_index" );
    # build indicator hash.
    my @ind_tag   = $input->param( "ind_tag_$item_index" );
    my @indicator = $input->param( "indicator_$item_index" );
    # my $itemnumber = $input->param( 'itemnumber' );
    my $xml = TransformHtmlToXml( \@tags, \@subfields, \@values, \@indicator, \@ind_tag, 'ITEM' );
    my @params = $input->param();
    my $itemtosave=MARC::Record::new_from_xml( $xml, 'UTF-8' );
    if ( !$itemnumber && C4::Context->preference( 'autoBarcode' ) eq 'incremental' ) {
        my ( $tagfield, $tagsubfield ) = &GetMarcFromKohaField( "items.barcode", $frameworkcode );
        unless ( $itemtosave->field( $tagfield )->subfield( $tagsubfield ) ) {
            my $sth_barcode = $dbh->prepare( "select max( abs( barcode ) ) from items" );
            $sth_barcode->execute;
            my ( $newbarcode ) = $sth_barcode->fetchrow;
            $newbarcode++;
            # OK, we have the new barcode, now create the entry in MARC record
            my $fieldItem = $itemtosave->field( $tagfield );
            $itemtosave->delete_field( $fieldItem );
            $fieldItem->add_subfields( $tagsubfield => $newbarcode );
            $itemtosave->insert_fields_ordered( $fieldItem );
        }
    }
    # MARC::Record builded => now, record in DB
    # warn "R: ".$record->as_formatted;
    # check that the barcode don't exist already
    my $addedolditem = TransformMarcToKoha( $dbh, $itemtosave );
    my $exist_itemnumber = get_item_from_barcode( $addedolditem->{'barcode'} );
    return ( $itemtosave, ( $exist_itemnumber && $exist_itemnumber != $itemnumber ) );
}

sub get_all_items {
    my ( $input, $frameworkcode ) = @_;

    my @items = $input->param( 'items' );

    return map { my ($item_record, $not_unique) = get_item_record( $input, $frameworkcode, $_ ); $item_record } @items;
}

=head2 set_form_values

    C4::Form::MessagingPreferences::set_form_value( { borrowernumber => 51 }, $template );

Retrieves the messaging preferences for the specified patron or patron category
and fills the corresponding template variables.

C<$target_params> is a hashref containing either a C<categorycode> key or a C<borrowernumber> key 
identifying the patron or patron category.

C<$template> is the HTML::Template::Pro object for the response.

=cut

=head2 get_form_values

    C4::Form::AddItem::get_form_values( $item_index, $existing_record );

Creates the item addition form, and returns an arrayref that can be used in a
template.

C<$item_index> The index, from 0, of the item ( used to distinguish multiple
forms, like on the import screen )

C<$existing_record> If basing this on an existing item/created item, this
should be the relevant MARC blob for that item.

=cut

sub get_form_values {
    my ( $tagslib, $item_index, $options ) = @_;
    $options ||= { };
    $options = {
        biblio => MARC::Record->new(),
        frameworkcode => '',
        omit => [],
        wipe => [],
        make_today => [],
        allow_repeatable => 1,
        %$options
    };
    my $dbh = C4::Context->dbh;
    my @loop_data =( );
    my $i=0;
    my $today_iso = C4::Dates->today( 'iso' );
    my $authorised_values_sth = $dbh->prepare( "SELECT authorised_value,lib FROM authorised_values WHERE category=? ORDER BY lib" );

    my $onlymine = C4::Context->preference( 'IndependantBranches' ) && 
                   C4::Context->userenv                           && 
                   C4::Context->userenv->{flags} % 2 == 0         && 
                   C4::Context->userenv->{branch};
    my $branches = GetBranchesLoop();  # build once ahead of time, instead of multiple times later.
    # restrict to only my work libraries
    if (@{$$options{worklibs} // []}) {
        my %br = (); # faster than grep
        foreach(@{$$options{worklibs}}) { $br{$_}=1 }
        my $tmp;
        foreach(@$branches) {
            push @$tmp, $_ if $br{$$_{value}};
        }
        $branches = $tmp;
    }

    my $item_defaults = new C4::Session::Defaults::Items();
    foreach my $tag ( sort keys %{$tagslib} ) {
        # loop through each subfield
        foreach my $subfield ( sort keys %{$tagslib->{$tag}} ) {
            next if subfield_is_koha_internal_p( $subfield );
            my $subfieldlib = $tagslib->{$tag}->{$subfield};
            next unless $subfieldlib;
            next unless defined $subfieldlib->{'tab'};
            next if ( $subfieldlib->{'tab'} ne "10" );
            next if ( $subfieldlib->{'kohafield'} && $options->{'omit'} && grep( { $_ eq $subfieldlib->{'kohafield'} } @{ $options->{'omit'} } ) ); 
            my %subfield_data;

            my $index_subfield = int( rand( 1000000 ) ); 
            if ( $subfield eq '@' ){
                $subfield_data{id} = "tag_".$tag."_subfield_00_".$index_subfield;
            } else {
                $subfield_data{id} = "tag_".$tag."_subfield_".$subfield."_".$index_subfield;
            }
            $subfield_data{item_index} = $item_index;
            $subfield_data{tag}        = $tag;
            $subfield_data{subfield}   = $subfield;
            $subfield_data{random}     = int( rand( 1000000 ));    # why do we need 2 different randoms?
            #   $subfield_data{marc_lib}   = $tagslib->{$tag}->{$subfield}->{lib};
            $subfield_data{marc_lib}   ="<span id=\"error$i\" title=\"".$subfieldlib->{lib}."\">".$subfieldlib->{lib}."</span>";
            $subfield_data{mandatory}  = $subfieldlib->{mandatory};
            $subfield_data{repeatable} = $subfieldlib->{repeatable} && $options->{'allow_repeatable'};
            my ( $indicator, $value ) = ( '', '' );
            ( $indicator, $value ) = _find_value( $tag,$subfield, $options->{'item'} ) if ( $options->{'item'} );
            $value = $item_defaults->get( field => $tag, subfield => $subfield ) unless ( $options->{'item'} );
            $value =~ s/"/&quot;/g if (defined $value);
            unless ( $value ) {
                $value = $subfieldlib->{defaultvalue} || '';
                # get today date & replace YYYY, MM, DD if provided in the default value
                my ( $year, $month, $day ) = split '-', $today_iso;
                $value =~ s/YYYY/$year/g;
                $value =~ s/MM/$month/g;
                $value =~ s/DD/$day/g;
            }
            if ($subfieldlib->{'kohafield'} && $options->{'wipe'} && grep ( {$_ eq $subfieldlib->{'kohafield'} } @{ $options->{'wipe'} }) ) {
                $value = "";
            }
            if ($subfieldlib->{'kohafield'} && $options->{'make_today'} && grep ( {$_ eq $subfieldlib->{'kohafield'} } @{ $options->{'make_today'}})) {
                $value = C4::Dates->today('iso');
            }

            $subfield_data{visibility} = "display:none;" if ( ($subfieldlib->{hidden} > 4 ) || ( $subfieldlib->{hidden} < -4 ));
            # testing branch value if IndependantBranches.
            my $pref_itemcallnumber = C4::Context->preference( 'itemcallnumber' );
            if ( !$value && $subfieldlib->{kohafield} eq 'items.itemcallnumber' && $pref_itemcallnumber ) {
                my $CNtag       = substr( $pref_itemcallnumber, 0, 3 );
                my $CNsubfield  = substr( $pref_itemcallnumber, 3, 1 );
                my $CNsubfield2 = substr( $pref_itemcallnumber, 4, 1 );
                my $temp2 = $options->{'biblio'}->field( $CNtag );
                if ( $temp2 ) {
                    $CNsubfield  //= undef;
                    $CNsubfield2 //= undef;
                    $value = ( $temp2->subfield( $CNsubfield ) // '')
                    .' '.( $temp2->subfield( $CNsubfield2 ) // '');
                    #remove any trailing space incase one subfield is used
                    $value =~ s/^\s+|\s+$//g;
                }
            }

            my $attributes_no_value = qq( tabindex="1" id="$subfield_data{id}" name="field_value_$item_index" class="input_marceditor" size="67" maxlength="255" );
            my $attributes          = qq( $attributes_no_value value="$value" );
            my @field_class_names   = ('input_marceditor',);
            if ( $subfieldlib->{authorised_value} || ($subfieldlib->{kohafield} eq "items.otherstatus") ) {
                my @authorised_values;
                my %authorised_lib;
                # builds list, depending on authorised value...

                if ( $subfieldlib->{authorised_value} eq "branches" ) {
                    foreach my $thisbranch (@$branches ) {
                        push @authorised_values, $thisbranch->{value};
                        $authorised_lib{$thisbranch->{value}} = $thisbranch->{'branchname'};
                        $value = $thisbranch->{value} if ( !$value && $thisbranch->{selected});
                    }
                }
                elsif ( $subfieldlib->{authorised_value} eq "itemtypes" ) {
                    push @authorised_values, "" unless ( $subfieldlib->{mandatory} );
                    my $sth = $dbh->prepare( "select itemtype,description from itemtypes order by description" );
                    $sth->execute;
                    my $itemtype;     # FIXME: double declaration of $itemtype
                    while ( my ( $itemtype, $description ) = $sth->fetchrow_array ) {
                        push @authorised_values, $itemtype;
                        $authorised_lib{$itemtype} = $description;
                    }

                    my ( $itemtype_tag, $itemtype_subfield ) = &GetMarcFromKohaField( "biblioitems.itemtype", $options->{'frameworkcode'} );
                    my $itemtype_field = $options->{'biblio'}->field( $itemtype_tag );
                    if ( !$value && $itemtype_field && $itemtype_field->subfield( $itemtype_subfield ) ) {
                        $value = $itemtype_field->subfield( $itemtype_subfield );
                    }

                    #---- class_sources
                }
                elsif ( $subfieldlib->{authorised_value} eq "cn_source" ) {
                    push @authorised_values, "" unless ( $subfieldlib->{mandatory} );

                    my $class_sources = GetClassSources( );
                    my $default_source = C4::Context->preference( "DefaultClassificationSource" );

                    foreach my $class_source ( sort keys %$class_sources ) {
                        next unless $class_sources->{$class_source}->{'used'} or
                        ( $value and $class_source eq $value )      or
                        ( $class_source eq $default_source );
                        push @authorised_values, $class_source;
                        $authorised_lib{$class_source} = $class_sources->{$class_source}->{'description'};
                    }
                    $value = $default_source unless ( $value );
                }
                elsif ( $subfieldlib->{kohafield} eq "items.otherstatus" ) {
                     push @authorised_values, "" unless ( $subfieldlib->{mandatory} );
                     my $sth = $dbh->prepare("SELECT statuscode,description FROM itemstatus ORDER BY description");
                     $sth->execute;
                     while ( my ( $statuscode, $description ) = $sth->fetchrow_array ) {
                          push @authorised_values, $statuscode;
                          $authorised_lib{$statuscode} = $description;
                     }
                }
                elsif ( $subfieldlib->{kohafield} eq "items.itemlost" ) {
                     %authorised_lib = %{C4::Items::get_itemlost_values()};
                     @authorised_values = keys %authorised_lib;
                }
                    #---- "true" authorised value
                else {
                    push @authorised_values, "" unless ( $subfieldlib->{mandatory} );
                    $authorised_values_sth->execute( $subfieldlib->{authorised_value} );
                    while ( my ( $value, $lib ) = $authorised_values_sth->fetchrow_array ) {
                        push @authorised_values, $value;
                        $authorised_lib{$value} = $lib;
                    }
                }
                if($subfieldlib->{kohafield}){
                    # Add class name for mapped koha fields.
                    push @field_class_names, substr($subfieldlib->{kohafield}, 6);
                }
                $subfield_data{marc_value} =CGI::scrolling_list( # FIXME: factor out scrolling_list
                    -name     => "field_value_$item_index",
                    -values   => \@authorised_values,
                    -default  => $value,
                    -labels   => \%authorised_lib,
                    -override => 1,
                    -size     => 1,
                    -multiple => 0,
                    -tabindex => 1,
                    -id       => "tag_".$tag."_subfield_".$subfield."_".$index_subfield,
                    -class    => join(' ', @field_class_names)
                );
                # it's a thesaurus / authority field
            }
            elsif ( $subfieldlib->{authtypecode} ) {
                $subfield_data{marc_value} = "<input type=\"text\" $attributes />
                <a href=\"#\" class=\"buttonDot\"
                onclick=\"Dopop( '/cgi-bin/koha/authorities/auth_finder.pl?authtypecode=".$subfieldlib->{authtypecode}."&index=$subfield_data{id}','$subfield_data{id}' ); return false;\" title=\"Tag Editor\">...</a>
                ";
                # it's a plugin field
            }
            elsif ( $subfieldlib->{value_builder} ) {
                # opening plugin
                my $plugin = C4::Context->intranetdir . "/cataloguing/value_builder/" . $subfieldlib->{'value_builder'};
                if ( do $plugin ) {
                    my $extended_param = plugin_parameters( $dbh, $options->{'biblio'}, $tagslib, $subfield_data{id}, \@loop_data );
                    my ( $function_name, $javascript ) = plugin_javascript( $dbh, $options->{'biblio'}, $tagslib, $subfield_data{id}, \@loop_data );
                    $subfield_data{marc_value} = qq[<input $attributes
                    onfocus="Focus$function_name( $subfield_data{random}, '$subfield_data{id}' );"
                    onblur=" Blur$function_name( $subfield_data{random}, '$subfield_data{id}' );" />
                    <a href="#" class="buttonDot" onclick="Clic$function_name( '$subfield_data{id}' ); return false;" title="Tag Editor">...</a>
                    $javascript];
                } else {
                    warn "Plugin Failed: $plugin";
                    $subfield_data{marc_value} = "<input $attributes />"; # supply default input form
                }
            }
            elsif ( $tag eq '' ) {       # it's an hidden field
                $subfield_data{marc_value} = qq( <input type="hidden" $attributes /> );
            }
            elsif ( $subfieldlib->{'hidden'} ) {   # FIXME: shouldn't input type be "hidden" ?
                $subfield_data{marc_value} = qq( <input type="text" $attributes /> );
            }
            elsif ( length( $value ) > 100
                    or ( C4::Context->preference( "marcflavour" ) eq "UNIMARC" and
                    300 <= $tag && $tag < 400 && $subfield eq 'a' )
                    or ( C4::Context->preference( "marcflavour" ) eq "MARC21"  and
                    500 <= $tag && $tag < 600                     )
            ) {
                # oversize field ( textarea )
                $subfield_data{marc_value} = "<textarea $attributes_no_value>$value</textarea>\n";
            } else {
                # it's a standard field
                $subfield_data{marc_value} = "<input $attributes />";
            }
            #   $subfield_data{marc_value}="<input type=\"text\" name=\"field_value\">";
            push ( @loop_data, \%subfield_data );
            $i++
        }
    }

    return \@loop_data;
}

sub _find_value {
    my ( $tagfield,$insubfield,$record ) = @_;
    my $indicator = '';
    my $result = '';
    foreach my $field ( $record->field( $tagfield )) {
        my @subfields = $field->subfields( );
        foreach my $subfield ( @subfields ) {
            if ( @$subfield[0] eq $insubfield ) {
                $result .= @$subfield[1];
                $indicator = $field->indicator( 1 ).$field->indicator( 2 );
            }
        }
    }
    return( $indicator,$result );
}

sub get_item_from_barcode {
    my ( $barcode )=@_;
    my $dbh=C4::Context->dbh;
    my $result;
    my $rq=$dbh->prepare( "SELECT itemnumber from items where items.barcode=?" );
    $rq->execute( $barcode );
    ( $result )=$rq->fetchrow;
    return( $result );
}

=head1 TODO

=over 4

=item Generalize into a system of form handler clases

=back

=head1 SEE ALSO

F<tools/stage-marc-import.pl>

=head1 AUTHOR

Jesse Weaver <pianohacker@gmail.com>

=cut

1;
