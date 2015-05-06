#!/usr/bin/env perl

# script to administer the systempref table
# written 20/02/2002 by paul.poulain@free.fr
# This software is placed under the gnu General Public License, v2 (http://www.gnu.org/licenses/gpl.html)

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

use Koha;
use CGI;
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Languages qw(getTranslatedLanguages);
use C4::ClassSource;
use C4::Log;
use C4::Output;

# Load any uninitialized sysprefs
our $prefdefs = C4::Context->preference_defaults;
C4::Context->preference($_) for (keys %$prefdefs);

sub StringSearch {
    my ( $searchstring, $type ) = @_;

    my ($where, @bind);
    if ( $type && $type ne 'all' ) { # search by tab
        @bind = grep {$prefdefs->{$_}{tags}[0] eq $type} keys %$prefdefs;
        $where = sprintf 'variable IN (%s)', (join ',', map '?', @bind);
    }
    else { # search by string
        $searchstring ||= 'gibberish and nonsense'; #find nothing by default
        @bind = ("%$searchstring%");
        $where = 'variable LIKE ?';
    }
    my $query = "SELECT variable, value FROM systempreferences WHERE $where ORDER BY variable";

    my $prefs = C4::Context->dbh->selectall_arrayref($query, {Slice=>{}}, @bind);
    $prefs = [
        grep { ! $prefdefs->{$_->{variable}}{hidden} }
        grep { exists $prefdefs->{$_->{variable}} }
        @$prefs
    ];
    for my $pref (@$prefs) {
        my $default = $prefdefs->{$pref->{variable}};
        for (qw/options explanation type/) {
            $pref->{$_} = $default->{$_};
        }
    }

    return $prefs;
}

sub GetPrefParams {
    my $data   = shift;
    my $params = $data;
    my @options;

    if ( defined $data->{'options'} ) {
        foreach my $option ( split( /\|/, $data->{'options'} ) ) {
            my $selected = '0';
            defined( $data->{'value'} ) and $option eq $data->{'value'} and $selected = 1;
            push @options, { option => $option, selected => $selected };
        }
    }

    $params->{'prefoptions'} = $data->{'options'};

    if ( not defined( $data->{'type'} ) ) {
        $params->{'type-free'} = 1;
        $params->{'fieldlength'} = ( defined( $data->{'options'} ) and $data->{'options'} and $data->{'options'} > 0 );
    } elsif ( $data->{'type'} eq 'Choice' ) {
        $params->{'type-choice'} = 1;
    } elsif ( $data->{'type'} eq 'YesNo' ) {
        $params->{'type-yesno'} = 1;
        $data->{'value'}        = C4::Context->boolean_preference( $data->{'variable'} );
        if ( defined( $data->{'value'} ) and $data->{'value'} eq '1' ) {
            $params->{'value-yes'} = 1;
        } else {
            $params->{'value-no'} = 1;
        }
    } elsif ( $data->{'type'} eq 'Integer' || $data->{'type'} eq 'Float' ) {
        $params->{'type-free'} = 1;
        $params->{'fieldlength'} = ( defined( $data->{'options'} ) and $data->{'options'} and $data->{'options'} > 0 ) ? $data->{'options'} : 10;
    } elsif ( $data->{'type'} eq 'Textarea' ) {
        $params->{'type-textarea'} = 1;
        $data->{options} //= '';
        $data->{options} =~ /(.*)\|(.*)/;
        $params->{'cols'} = $1;
        $params->{'rows'} = $2;
    } elsif ( $data->{'type'} eq 'Themes' ) {
        $params->{'type-choice'} = 1;
        my $type = '';
        ( $data->{'variable'} =~ m#opac#i ) ? ( $type = 'opac' ) : ( $type = 'intranet' );
        @options = ();
        my $currently_selected_themes;
        my $counter = 0;
        foreach my $theme ( split /\s+/, $data->{'value'} ) {
            push @options, { option => $theme, counter => $counter };
            $currently_selected_themes->{$theme} = 1;
            $counter++;
        }
        foreach my $theme ( getallthemes($type) ) {
            my $selected = '0';
            next if $currently_selected_themes->{$theme};
            push @options, { option => $theme, counter => $counter };
            $counter++;
        }
    } elsif ( $data->{'type'} eq 'ClassSources' ) {
        $params->{'type-choice'} = 1;
        my $type = '';
        @options = ();
        my $sources = GetClassSources();
        my $counter = 0;
        foreach my $cn_source ( sort keys %$sources ) {
            if ( $cn_source eq $data->{'value'} ) {
                push @options, { option => $cn_source, counter => $counter, selected => 1 };
            } else {
                push @options, { option => $cn_source, counter => $counter };
            }
            $counter++;
        }
    } elsif ( $data->{'type'} eq 'Languages' ) {
        my $currently_selected_languages;
        foreach my $language ( split /\s+/, $data->{'value'} ) {
            $currently_selected_languages->{$language} = 1;
        }

        # current language
        my $lang = $params->{'lang'};
        my $theme;
        my $interface;
        if ( $data->{'variable'} =~ /opac/ ) {

            # this is the OPAC
            $interface = 'opac';
            $theme     = C4::Context->preference('opacthemes');
        } else {

            # this is the staff client
            $interface = 'intranet';
            $theme     = C4::Context->preference('template');
        }
        my $languages_loop = getTranslatedLanguages( $interface, $theme, $lang, $currently_selected_languages );

        $params->{'languages_loop'}    = $languages_loop;
        $params->{'type-langselector'} = 1;
    } else {
        $params->{'type-free'} = 1;
        $params->{'fieldlength'} = ( defined( $data->{'options'} ) and $data->{'options'} and $data->{'options'} > 0 ) ? $data->{'options'} : 30;
    }

    if ( $params->{'type-choice'} || $params->{'type-free'} || $params->{'type-yesno'} ) {
        $params->{'oneline'} = 1;
    }

    $params->{'preftype'} = $data->{'type'};
    $params->{'options'}  = \@options;

    return $params;
}

my $input       = new CGI;
my $searchfield = $input->param('searchfield') || '';
my $Tvalue      = $input->param('Tvalue');
my $offset      = $input->param('offset') || 0;
my $script_name = "/cgi-bin/koha/admin/systempreferences.pl";

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   template_name   => "admin/systempreferences.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 1 },
        debug           => 1,
    }
);
my $pagesize = 100;
my $op = $input->param('op') || '';
$searchfield =~ s/\,//g;

if ($op) {
    $template->param(
        script_name => $script_name,
        $op         => 1
    );    # we show only the TMPL_VAR names $op
} else {
    $template->param(
        script_name => $script_name,
    );    # we show only the TMPL_VAR names $op
}

################## ADD_FORM ##################################
# called by default. Used to create form to add or  modify a record

if ( $op eq 'add_validate' ) {
    my $variable = $input->param('variable');
    # to handle multiple values
    my $value;

    # handle multiple value strings (separated by ',')
    my $params = $input->Vars;
    if ( defined $params->{'value'} ) {
        my @values = ();
        @values = split( "\0", $params->{'value'} ) if defined( $params->{'value'} );
        if (@values) {
            $value = "";
            for my $vl (@values) {
                $value .= "$vl,";
            }
            $value =~ s/,$//;
        } else {
            $value = $params->{'value'};
        }
    }
    unless ( C4::Context->config('demo') ) {
        C4::Context->preference_set($variable, $value);
        logaction( 'SYSTEMPREFERENCE', 'MODIFY', undef, $variable . " | " . $value );
    }
    my $tab = $prefdefs->{$variable}{tags}[0];
    print "Content-Type: text/html\n\n<META HTTP-EQUIV=Refresh CONTENT=\"0; URL=systempreferences.pl?tab=$tab\"></html>";
    exit;

################## DEFAULT ##################################
} else {    # DEFAULT
    #Adding tab management for system preferences
    my $tab = $input->param('tab');
    $template->param( $tab => 1 );
    my $results = StringSearch( $searchfield, $tab );
    $template->param( searchfield => $searchfield );
    my $count = @$results;
    my @loop_data = ();
    for ( my $i = $offset ; $i < ( $offset + $pagesize < $count ? $offset + $pagesize : $count ) ; $i++ ) {
        my $row_data = $results->[$i];
        $row_data->{'lang'} = $template->param('lang');
        $row_data           = GetPrefParams($row_data);                                                         # get a fresh hash for the row data
        $row_data->{edit}   = "$script_name?op=add_form&amp;searchfield=" . $results->[$i]{'variable'};
        $row_data->{delete} = "$script_name?op=delete_confirm&amp;searchfield=" . $results->[$i]{'variable'};
        push( @loop_data, $row_data );
    }
    $template->param( loop => \@loop_data, $tab => 1 );
    if ( $offset > 0 ) {
        my $prevpage = $offset - $pagesize;
        $template->param( "<a href=$script_name?offset=" . $prevpage . '&lt;&lt; Prev</a>' );
    }
    if ( $offset + $pagesize < $count ) {
        my $nextpage = $offset + $pagesize;
        $template->param( "a href=$script_name?offset=" . $nextpage . 'Next &gt;&gt;</a>' );
    }
    $template->param( tab => $tab, );
}    #---- END $OP eq DEFAULT
output_html_with_http_headers $input, $cookie, $template->output;
