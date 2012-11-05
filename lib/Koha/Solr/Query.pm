package Koha::Solr::Query;

# Allows caller to pass in a CGI object
# representing a form submitted to Koha,
# and builds query.  Also handles default
# sort, requestHandler, etc.
# Constructor should be called with one of:
# cgi => CGI object,
# url => url-encoded string with search params
# query and options.
# It would be nice if you could specify query and options
# without having to create a WS::Solr::Query object, possibly TODO
#

use Koha;
use Moose;
use Method::Signatures;
use WebService::Solr::Query;
use URI::Escape;
use List::MoreUtils qw(each_array);
use Business::ISBN;

use C4::Context;
use C4::Branch;

has rtype => ( is => 'ro', isa => 'Str', default => 'bib' );
has opac => ( is => 'ro', isa => 'Bool' );
has options => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );
has query => ( is => 'rw', isa => 'Str', default => '*:*' );
has cgi => ( is => 'rw', isa => 'CGI' );
has uri => ( is => 'rw', isa => 'Str' );
has limits => ( is => 'rw', isa => 'ArrayRef' );
has simple_query => (is => 'rw', isa => 'Str', default => '*:*' );  # if search is only against one field.
has simple_query_field => ( is => 'rw', isa => 'Str' );
has looks_like_barcode => ( is => 'rw',
                            isa => 'Str',
                            );  # If a query term looks like a barcode, we store it here.
has z3950_param => ( is => 'rw', isa => 'HashRef' ); # so we can build a z3950 query from this query.

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    if ( @_ == 1 && ref $_[0] eq 'CGI' ) {
        return $class->$orig( cgi => $_[0] );
    } else {
        return $class->$orig(@_);
    }
    
};

sub BUILD {
    my $self = shift;
    if($self->cgi()){
        #TODO: Split this depending on rtype.
        $self->_build_query_from_cgi();
    } elsif($self->uri()){
        $self->_build_query_from_url();  # This may not be necessary; parameterized uri can be parsed by CGI.
    } elsif($self->query()){
        #hack to cause "around" method mod to run
        $self->query( $self->query );

        my $options = $self->options;
        $options->{qt} = ($self->rtype eq 'bib') ? 'biblio' : 'authority';
        $self->options($options);
    } else {
        die "__PACKAGE__ Must be instantiated with a cgi object or search query";
    }
}

around 'query' => sub {
    my ($orig, $self, $q) = @_;

    return $self->$orig() unless $q;

    # Convert simple queries like "ti:some title phrase" to
    # "ti:(some title phrase)", but ignore ones like
    # "ti:some au:(first last)" or "ti:some au:name"
    unless ($q =~ /[()"]/ || $q =~ /:.*:/) {
        $q =~ s/^(\w+):(.*)/$1:\($2\)/;
    }

    # give extra boost to phrasal matches for title searches
    if ( $q =~ /^ti(?:tle)? : \( ([^\)]+) \)$/x ) {
        my $options = $self->options;
        $options->{bq} //= [];
        push $options->{bq}, qq{title-nostem:"$1"~10^5};
    }

    return $self->$orig($q);
};

#method _build_query_from_cgi {
sub _build_query_from_cgi{
    my $self = shift;
    
    # should have a way to test for valid index names.
    my $cgi = $self->cgi();

    my $query = '';
    my $options = $self->options;
    my $z3950_param = {};
    my $params = each_array(
        @{[$cgi->param('q')]},
        @{[$cgi->param('idx')]},
        @{[undef, $cgi->param('op')]} # pad the ops
        );

    while ( my ($q, $idx, $op) = $params->() ) {
        next unless $q;

        $query .= sprintf ' %s ', uc($op)
            if $query;

        if ( !$idx ) {
            # user may have specified field. In this case, we assume
            # they used proper syntax. (should only happen when idx=='').
            $query .= $q;
        }
        else {
            if( $idx eq 'barcode' ) {
                # If barcode search, expand with prefix.
                $q = C4::Circulation::barcodedecode(barcode => $q);
                $self->looks_like_barcode($q);
            }
            elsif ( $idx eq 'isbn' ) {
                # Normalize ISBN
                my $isbn = Business::ISBN->new($q);
                $q = $isbn->isbn if $isbn;
            }
            elsif ( $idx eq 'callnumber' ) {
                # Do a left-anchored wildcard search on call numbers
                $q =~ s/\s+/?/g;
                $q .= '*';
            }
            elsif( $q !~ /"/ && $q !~ /\(|\)/ && $q =~ /\S+\s+\S+/ ) {
                # Add grouping for this field if not quoted and multiple terms.
                $q = "($q)";
            }
            $query .= "$idx:$q";
        }

        # FIXME: This would be better placed within the z3950 search
        # script, but since we don't have a query parser in place, we
        # stash it in the query object to prevent having to parse the
        # query in that script.
        my @fields =  qw/ title lccn isbn issn title author dewey subject /;
        if ( grep($idx, @fields) ) {
            $z3950_param->{$idx} =
                ($z3950_param->{$idx}) ? $z3950_param->{$idx} . ' ' . $q : $q;
        }
        elsif ( !$idx ) {
            my ($f, $term) = split(':', $q);
            # FIXME:Note any/srchany doesn't actually work in z3950_search.pl
            ($f = 'any', $term = $q)
                unless ( $f ~~ [@fields] );
            $z3950_param->{$f} =
                ($z3950_param->{$f}) ? $z3950_param->{$f} . ' ' . $term : $term;
        }
    }
    $self->z3950_param($z3950_param);

    # set simple query params so masthead can rebuild form elements.
    # If user has entered a multi-field query, don't do it.
    # FIXME: This regex won't do what we want on quoted queries.
    my $queried_fields = () = $query =~ /\w+:/g;
    if($queried_fields < 2){
        my ($f,$qstr) = split(/:\s*/,$query);
        $f //= '';
        if($qstr){
            $self->simple_query($qstr);
            $self->simple_query_field($f);
        } else {
            $self->simple_query($f);
            # A single-field query on a numeric term will be translated into barcode / biblionumber search.
            if( !$self->opac && ($f !~ /\D/)){
                my $expectedLen = C4::Context->preference('itembarcodelength');
                my $l = length($f);
                if (($l < $expectedLen) && ($l != 10) && ($l != 13) && ($l > 1)) {
                    my $prefixed_bc = C4::Circulation::barcodedecode(barcode => $f);
                    $query = sprintf("barcode:%s OR biblionumber:%d",$prefixed_bc,$f); 
                    $self->looks_like_barcode($prefixed_bc);
                }
            }
        }
    } else {
        # We could pass the whole advanced query back here.
        # Should probably be syspref controlled, as only advanced users would want it.
        # $self->simple_query($query);
    }
    
    $query =~ s/ ^\*+$ | ^[^a-z0-9]*$ /*:*/ix; # set a last-resort default

    $self->query($query);

    # Assemble options
     # for now just single sort.
    my $sort = $cgi->param('sort') || $cgi->param('sort_by');
    my $sort_syspref = ($self->opac) ? 'OPACdefaultSortField' : 'defaultSortField';
    my $order_syspref = ($self->opac) ? 'OPACdefaultSortOrder' : 'defaultSortOrder';
    if(!$sort && C4::Context->preference($sort_syspref) && C4::Context->preference($sort_syspref) ne 'score'){
        $sort = C4::Context->preference($sort_syspref)." ".C4::Context->preference($order_syspref)
    }

    my @userlimits = grep {$_} $cgi->param('limit');
    # For ccode, itemtype, location limits, assumed operator is OR.
    my (@ccodelimit,@itypelimit,@loclimit);
    my @systemlimits = ();
    if($cgi->param('itypelimit')){
        push @userlimits, 'itemtype:("' . join('" OR "',$cgi->param('itypelimit')) . '")';
    }
    if($cgi->param('ccodelimit')){
        push @userlimits, 'collection:("' . join('" OR "',$cgi->param('ccodelimit')) . '")';
    }
    if($cgi->param('loclimit')){
        push @userlimits, 'location:("' . join('" OR "',$cgi->param('loclimit')) . '")';
    }
    if($cgi->param('multibranchlimit')){
        my ($field,$branchcat) = split(':',$cgi->param('multibranchlimit'));
        if(!$branchcat){
            $branchcat = $field;
            $field = 'owned-by';
        }
        my @branches = @{GetBranchesInCategory($branchcat)};
        push @userlimits, sprintf("%s:(%s)", $field, join(' OR ', map {"\"$_\""} @branches)) if @branches;
    }

    # append year limits if they exist
    # Note fq format date:[1980 TO *]
    # pub-date is a string!
    if (my $date_str = $cgi->param('date') || $cgi->param('limit-yr')) {
        $date_str =~ s/\s//g;
        if ($date_str =~ /-/) {
            my ($yr1,$yr2) = split(/-/, $date_str);
            push @userlimits, sprintf("pubyear:[%s TO %s]",$yr1 || '*', $yr2 || '*');
        }
        elsif ($date_str =~ /\d{4}/) {
            push @userlimits, "pubyear:$date_str";
        }
        else {
            #FIXME: Should return an error to the user, incorect date format specified
        }
    }
    # add bib-level OPAC suppression
# TODO: should probably split deleted status from suppression.
    if($self->opac()){
        push @systemlimits, 'suppress:0';
        if (C4::Context->preference('hidelostitems') == 1) {
            # either lost ge 0 or no value in the lost register
            push @systemlimits, 'lost:[* TO 0]';
        }
    } else {
        push(@systemlimits, 'suppress:[0 TO 1]') unless(grep(/^suppress:/, @userlimits));
    }

    my @fq = (@userlimits, @systemlimits);

    my $results_per_page = C4::Context->preference('OPACnumSearchResults');
    my $offset = $cgi->param('offset') || 0;
    my $page = $cgi->param('page') || 1;
    $options->{fq} = \@fq if(@fq);
    $options->{'sort'} = $sort if $sort;
    $options->{start} = $offset;
    $options->{rows} = $results_per_page;
    # $options->{echoParams} = 'explicit';  # WS::Solr needs to get rows back from solr for Data::Pageset.  (set in handler config).
    #
    # TODO: possibly allow request handler to be specified.
    $options->{qt} = ($self->rtype() eq 'bib') ? 'biblio' : 'authority';
    my $query_uri = "q=" . uri_escape($query);

    $query_uri .= "&sort=" . $sort if $sort;
    $query_uri .= "&limit=" . uri_escape(join(' ',@userlimits)) if(@userlimits);
    # FIXME: We store some fields in Solr as coded values, others as display values.
    # Should try to be more consistent, and have a reusable mechanism for translation on the display layer.
    #for @userlimits{
    #    my ($field,$val) = split(':',@userlimits,2);
    #    push @limit_loop, { limit_field => $field, limit_label => facet_label($field), limit_value => $val, limit_display_val => facet_val($val) };
    #}
    my @limit_loop = map { limit_desc => $_ , limit => $_ }, @userlimits;

    #explicitly request facets.
    my @facets = map {/(\S*):/; $1;} split(/\s*,\s*/,C4::Context->preference('SearchFacets'));
    $options->{'facet.field'} = \@facets;

    # DidYouMean?
    # Solr 4.0 should yeild some better results.  For now, with Solr 3.6,
    # we get twice as many collations back as the suggestionscount syspref,
    # and trim and order them by hits on display.
    my $suggest_cnt = C4::Context->preference( ($self->opac) ? 'OPACSearchSuggestionsCount' : 'StaffSearchSuggestionsCount') * 2;
    if($suggest_cnt){
        $options->{'spellcheck'} = 'true';
        $options->{'spellcheck.collate'} = 'true';
        $options->{'spellcheck.count'} = $suggest_cnt;
        $options->{'spellcheck.maxCollations'} = $suggest_cnt;
        #$options->{'spellcheck.collateParam.mm'}='100%'; # maybe unnecessary, maybe not escaped properly.
        # Note that spellcheck.onlyMorePopular should be set to FALSE, else collations won't include properly spelled terms.
    } else {
        $options->{spellcheck} = 'false';
    }

    $self->options($options);
    $self->uri($query_uri);
    $self->limits(\@limit_loop);

}

method z3950_uri_param () {
    return join('&', map( "$_=" . uri_escape($self->z3950_param()->{$_}), keys($self->z3950_param())));
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
