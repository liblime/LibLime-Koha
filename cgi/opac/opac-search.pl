#!/usr/bin/env perl
# Script to perform searching
# Mostly copied from search.pl, see POD there

## STEP 1. Load things that are used in both search page and
# results page and decide which template to load, operations 
# to perform, etc.
## load Koha modules
use Koha;
use Try::Tiny;
use C4::Context;
use C4::Output;
use C4::Auth qw(:DEFAULT get_session);
use C4::Search;
use C4::Biblio;  # GetBiblioData
use C4::Koha;
use C4::Tags qw(get_tags);
use C4::Languages qw(getAllLanguages);
use POSIX qw(ceil floor strftime);
use C4::Branch; # GetBranches
use Encode;
use C4::XSLT;
use MARC::Record;
use URI::Escape;
use Koha::Pager;
use DDP;

my $DisplayMultiPlaceHold = C4::Context->preference("DisplayMultiPlaceHold");
# create a new CGI object
# FIXME: no_undef_params needs to be tested
use CGI qw('-no_undef_params');
my $cgi = CGI->new();

use CHI;
use Digest::SHA1;
use Storable;
use vars qw($cache $MRXorig);

# This is not intended to be a long-term cache, but one that persists for
# only the duration one might expect to page around some search results.
# The max_size may need to be increased for very busy sites.

no warnings qw(redefine);
$cache = CHI->new(driver => 'RawMemory', global => 1,
                  max_size => 3_000_000, expires_in => 120);
$MRXorig = \&MARC::Record::new_from_xml;
local *MARC::Record::new_from_xml = \&MRXcached;

sub MRXcached {
    my $xml = shift;
    $xml = shift
        if $xml eq 'MARC::Record';
    my @args = @_;

    # Cat the record's top and bottom to maximize probability of uniqueness.
    my $matchme = substr($xml, 0, 255) . substr($xml, -255);
    my $key = Digest::SHA1::sha1( Encode::encode_utf8($matchme) );

    my $record = $cache->compute( $key, '1m', sub { $MRXorig->($xml, @args)} );

    return ($record) ? $record->clone : undef;
};

my ($template,$borrowernumber,$cookie);

# searching with a blank 'q' matches everything
if (!$cgi->param('q') && defined $cgi->param('q') ) {
    $cgi->param('q' => '*');
}

# decide which template to use
my $template_name;
my $search_form = 1;

my $format = $cgi->param("format") || '';
if ($format =~ /(rss|atom|opensearchdescription)/) {
	$template_name = 'opac-opensearch.tmpl';
} elsif ($cgi->param("q")) {
	$template_name = 'opac-results.tmpl';
    $search_form = 0;
} else {
    $template_name = 'opac-advsearch.tmpl';
}
# load the template
($template, $borrowernumber, $cookie) = get_template_and_user({
    template_name => $template_name,
    query => $cgi,
    type => "opac",
    authnotrequired => 1,
    }
);

if ($format eq 'rss2' or $format eq 'opensearchdescription' or $format eq 'atom') {
	$template->param($format => 1);
    $template->param(timestamp => strftime("%Y-%m-%dT%H:%M:%S-00:00", gmtime)) if ($format eq 'atom'); 
    # FIXME - the timestamp is a hack - the biblio update timestamp should be used for each
    # entry, but not sure if that's worth an extra database query for each bib
}
$template->param( 'AllowOnShelfHolds' => C4::Context->preference('AllowOnShelfHolds') );

if (C4::Context->preference('BakerTaylorEnabled')) {
    require C4::External::BakerTaylor;
    $template->param(
        BakerTaylorEnabled  => 1,
        BakerTaylorImageURL => C4::External::BakerTaylor::image_url(),
        BakerTaylorLinkURL  => C4::External::BakerTaylor::link_url(),
        BakerTaylorBookstoreURL => C4::Context->preference('BakerTaylorBookstoreURL'),
	);
}

if (C4::Context->preference('TagsEnabled')) {
	$template->param(TagsEnabled => 1);
	foreach (qw(TagsShowOnList TagsInputOnList)) {
		C4::Context->preference($_) and $template->param($_ => 1);
	}
}

# The following should only be loaded if we're bringing up the advanced search template
if ( $search_form ) {
    # load the branches
    my $mybranch = ( C4::Context->preference('SearchMyLibraryFirst') && C4::Context->userenv && C4::Context->userenv->{branch} ) ? C4::Context->userenv->{branch} : '';
    $template->param(
        branchloop              => GetBranchesLoop($mybranch, 0),
        searchdomainloop        => GetBranchCategories(undef,'searchdomain'),
        search_languages_loop   => getAllLanguages(),
        search_form             => 1,
    );
    my $itemtypes = GetItemTypes;
    my @itemtypesloop;
    my @ccodesloop;
    
    my $cnt = 0;
    my @advanced_search_limits = (C4::Context->preference("OPACAdvancedSearchLimits")) ? split(/\|/,C4::Context->preference("OPACAdvancedSearchLimits")) : ();
    
    if ( grep(/ItemTypes/i,@advanced_search_limits) ) {
    	foreach my $thisitemtype ( sort {$itemtypes->{$a}->{'description'} cmp $itemtypes->{$b}->{'description'} } keys %$itemtypes ) {
            my %row =(  number=>$cnt++,
    				field => 'itemtype',
                    code => $thisitemtype,
                    description => $itemtypes->{$thisitemtype}->{'description'},
                    count5 => $cnt % 4,
                    imageurl=> getitemtypeimagelocation( 'opac', $itemtypes->{$thisitemtype}->{'imageurl'} ),
                );
        	push @itemtypesloop, \%row;
    	}
        $template->param(itemtypeloop => \@itemtypesloop, ItemTypeLimit => 'ItemTypes');
    }
    if ( grep(/CCodes/i,@advanced_search_limits)  ) {
        $cnt = 0;
        my $advsearchtypes = GetAuthorisedValues('CCODE');
    	for my $thisitemtype (sort {$a->{'lib'} cmp $b->{'lib'}} @$advsearchtypes) {
    		my %row =(
    				number=>$cnt++,
                    field => 'collection',
                    code => $thisitemtype->{authorised_value},
                    description => $thisitemtype->{'lib'},
                    count5 => $cnt % 4,
                    imageurl=> getitemtypeimagelocation( 'opac', $thisitemtype->{'imageurl'} ),
                );
            push @ccodesloop, \%row;
    	}
        $template->param(ccodeloop => \@ccodesloop, CCodeLimit => 'CCodes');
    }
    if ( grep(/ShelvingLocations/i,@advanced_search_limits)  ) {
        my @shelvinglocsloop;
        $cnt = 0;
        my $shelflocations =GetAuthorisedValues("LOC");
        for my $thisloc (sort {$a->{'lib'} cmp $b->{'lib'}} @$shelflocations) {
            my %row =(
                    number => $cnt++,
                    field => 'location',
                    code => $thisloc->{authorised_value},
                    description => $thisloc->{'lib'},
                    count5 => $cnt % 4,
                  );
            push @shelvinglocsloop, \%row;
        }
        $template->param(shelvinglocsloop => \@shelvinglocsloop,ShelvingLocationLimit => 'ShelvingLocations');
    }

    {
        use Koha::Format;
        my %cat_desc = Koha::Format->new->all_descriptions_by_category;
        my @formatsloop;
        for ( qw(print video audio computing) ) {
            push @formatsloop,
                { labels =>
                      [ map {{description=>$_}} @{$cat_desc{$_}} ]
                };
        }
        $template->param( formatsloop => \@formatsloop);
    }

    $template->param(DisplayAdvancedSearchLimits => ($#advanced_search_limits) ? 1 : 0,);
    $template->param(DateRangeLimit => 'DateRange') if grep(/DateRange/i,@advanced_search_limits);
    $template->param(SubtypeLimit => 'Subtypes') if grep(/Subtypes/i,@advanced_search_limits);
    $template->param(LanguageLimit => 'Language') if grep(/Language/i,@advanced_search_limits);
    $template->param(LocationLimit => 'LocationAvailability') if grep(/LocationAvailability/i,@advanced_search_limits);
    $template->param(SortByLimit => 'SortBy') if grep(/SortBy/i,@advanced_search_limits);

    # set the default sorting
    if (C4::Context->preference('OPACdefaultSortField') && C4::Context->preference('OPACdefaultSortOrder')){
        my $default_sort_by = C4::Context->preference('OPACdefaultSortField')."_".C4::Context->preference('OPACdefaultSortOrder') ;
        $template->param($default_sort_by => 1);
    }

    my $expand_options = C4::Context->preference("expandedSearchOption");
    my $search_boxes_count = C4::Context->preference("OPACAdvSearchInputCount") || 3;
    my @search_boxes_array = map({}, (1..$search_boxes_count)); # HTML::Template needs a hashref.
    $template->param( advsearch => 1,
                      search_boxes_loop => \@search_boxes_array,
                      #search_boxes_loop => [1..$search_boxes_count],
                      expanded_options => $expand_options, );

    output_html_with_http_headers $cgi, $cookie, $template->output;
    exit;
}

### If we're this far, we're performing an actual search


# if a simple index (only one)  display the index used in the top search box
# TODO: Fix this, also add memory for format limit box.
#if ($indexes[0] && !$indexes[1]) {
#    $template->param("ms_".$indexes[0] => 1);
#}



# TODO: Reinstate spell check


## DO THE SEARCH AND GET THE RESULTS
my $total = 0; # the total results for the whole set
my $facets; # this object stores the faceted results that display on the left-hand of the results page
use Koha::Solr::Service;
use Koha::Solr::Query;

# Check for a title browse query
if ($cgi->param('idx') ~~ 'title-browse') {
    my $offset = $cgi->param('offset');
    unless ( defined $offset ) {
        # determine the proper offset value
        $cgi->param('idx' => 'title-sort');
        $cgi->param('q' => ('[* TO '. $cgi->param('q') .']') );
        my $solr = new Koha::Solr::Service;
        my $solr_query
            = Koha::Solr::Query->new({cgi => $cgi, opac => 1, rtype => 'bib'});
        my $rs = $solr->search( $solr_query->query, $solr_query->options );
        my $hits = $rs->content->{response}{numFound};
        $offset = $hits - 1;
    }

    # now override with the browse parameters
    $cgi->delete('idx');
    $cgi->param('q' => '*');
    $cgi->param('sort' => 'title-sort asc');
    $cgi->param('offset' => $offset);
}

my $solr = new Koha::Solr::Service;

my $solr_query = Koha::Solr::Query->new({cgi => $cgi, opac => 1, rtype => 'bib'});

if($solr_query->simple_query){
    my $q = $solr_query->simple_query();
    my $idx = $solr_query->simple_query_field();
    if ( $idx ) {
        $q =~ s/^\(|\)$//g;
    }
    $template->param( ms_query => $q, ms_idx => $idx );
}

my $rs = $solr->search($solr_query->query,$solr_query->options);

if(!$rs->is_error){

    my $results = $rs->content;
    if($results->{spellcheck}->{suggestions}){

        my %spell = ();
        for(my $i = 0; $i<@{$results->{spellcheck}->{suggestions}}; $i=$i+2){
            # suggestions come back as array, first individual terms, then collations.
            # for now, we ignore the terms and just use collations.
            next unless $results->{spellcheck}->{suggestions}[$i] ~~ 'collation';
            $spell{$results->{spellcheck}->{suggestions}[$i+1]->[1]} = $results->{spellcheck}->{suggestions}[$i+1]->[3];
            # i.e. collationQuery => hits  // would be safer to read the array into a hash, but this will probably change before long.
        }
        my $suggest_cnt = C4::Context->preference('OPACSearchSuggestionsCount');
        my @didyoumean = map { term => $_ }, sort { $spell{$b} <=> $spell{$a} } keys(%spell);
        @didyoumean = @didyoumean[0 .. $suggest_cnt-1] if(scalar(@didyoumean)>$suggest_cnt);
        $template->param( didyoumean => \@didyoumean );
    }

    my $hits = $results->{'response'}->{'numFound'};
    my $maxscore = $results->{'response'}->{'maxScore'};
    # TODO: If maxScore < 1 (or 0.2, say), offer 'did you mean'.
    # TODO: If $hits < ~8, offer 'expand search results'.

    $template->param( 'user_query' => $solr_query->query,
                      'user_limit' => $solr_query->limits,  # Note this is an arrayref, not a string.
                      'user_sort'  => $solr_query->options->{'sort'},
                      'query_uri'  => $solr_query->uri,
                      'solr_fq'    => join(' ', @{$solr_query->options->{'fq'}}),
            );

    my @newresults = (); # @{$results->{response}->{docs}};
    my $offset = $results->{'response'}->{'start'};
    my $i = 0;
    foreach my $doc (@{$results->{response}->{docs}}){
        $i++;
        my $bib = C4::Search::searchResultDisplay($doc, 1);
        $bib->{result_number} = $offset + $i;
        push @newresults, $bib;
    }

    ## If there's just one result, redirect to the detail page # TODO: Merge marcdetail and isbddetail into opac-detail
    if ($hits == 1) {         
        my $url = "/cgi-bin/koha/opac-detail.pl?biblionumber=" . $newresults[0]->{biblionumber};
        my $fmt = (C4::Context->preference('BiblioDefaultView') eq 'normal') ? '' : C4::Context->preference('BiblioDefaultView');
        $url .= "&format=$fmt" if $fmt;
        print $cgi->redirect($url);
        exit;
    } elsif ($hits) {
        $template->param(total => $hits,
                        DisplayMultiPlaceHold => C4::Context->preference("DisplayMultiPlaceHold"),
                        searchdesc => 1,
                        SEARCH_RESULTS => \@newresults,
                        OPACItemsResultsDisplay => (C4::Context->preference("OPACItemsResultsDisplay") eq "itemdetails"?1:0),
                        facets_loop => $rs->koha_facets(),
                        last_query => $solr_query->query(),
                        offset => $offset,  # for rss
                        pager => Koha::Pager->new({pageset => $rs->pageset})->tmpl_loop(),
                        );
    } else {
        # no hits
        # Offer a fuzzy search, perhaps.
        $template->param(total => $hits,
                        searchdesc => 1,
                        last_query => $solr_query->query(),
                        );
    }

} else {
    $template->param( query_error => 1);
    warn p $rs->raw_response;
}

# Lastly, results-independent tmpl vars.
# Build drop-down list for 'Add To:' menu...
my $session = get_session($cgi->cookie("CGISESSID"));
my @addpubshelves;
my $pubshelves = $session->param('pubshelves');
my $barshelves = $session->param('barshelves');
foreach my $shelf (@$pubshelves) {
	next if ( ($shelf->{'owner'} != ($borrowernumber ? $borrowernumber : -1)) && ($shelf->{'category'} < 3) );
	push (@addpubshelves, $shelf);
}

if (@addpubshelves) {
	$template->param( addpubshelves     => scalar (@addpubshelves));
	$template->param( addpubshelvesloop => \@addpubshelves);
}

if (defined $barshelves) {
	$template->param( addbarshelves     => scalar (@$barshelves));
	$template->param( addbarshelvesloop => $barshelves);
}

my $content_type = ($format eq 'rss' or $format eq 'atom') ? $format : 'html';

# If GoogleIndicTransliteration system preference is On Set paramter to load Google's javascript in OPAC search screens 
if (C4::Context->preference('GoogleIndicTransliteration')) {
        $template->param('GoogleIndicTransliteration' => 1);
}

output_with_http_headers $cgi, $cookie, $template->output, $content_type;

