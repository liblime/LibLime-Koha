package Koha::Solr::Service;

# This is just a convenience wrapper to hide the 
# mechanism for determining which solr server to
# hit.  Also approximates C4::Search's old SimpleSearch interface,
# and monkeypatches WS::Solr::Response to include koha- specific facet method.


use Moose;
use Method::Signatures;
use C4::Context;
use Koha::Solr::Query;

extends 'WebService::Solr';

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    if ( @_ == 0 ) {
        my $server = C4::Context->config('solr')->{url};
        return $class->$orig($server);
    } else {
        return $class->$orig(@_);
    }
};

method simpleSearch ( Koha::Solr::Query $query, Bool :$display ) {
    # analog of C4::Search::SimpleSearch.
    # returns just an arrayref of docs, the total number of hits, and a pager object.
    # if display => 1, then it passes results through C4::Search::searchResults adding display elements to the hashes.
    my $rs = $self->search($query->query,$query->options);
    if($rs->is_error){
        return( undef, 0);
    } else {
        my @docs = ($display) ? map(C4::Search::searchResultDisplay($_),@{$rs->content()->{response}->{docs}}) : @{$rs->content()->{response}->{docs}};
        return( \@docs, $rs->content->{'response'}->{'numFound'} );
    }
}

# Hack facet handling into WS::Solr::Response...

use DDP;

my $koha_facets = sub {
    my $self = shift;
    return unless C4::Context->preference('SearchFacets');
    my $facet_spec = C4::Context->preference('SearchFacets');
    my @facets;
    my $hits = $self->content->{response}->{numFound};
    for my $facetspec (split(/\s*,\s*/,C4::Context->preference('SearchFacets'))){
        my ($field, $display) = split(':',$facetspec);
        $display = $field unless $display;
        my $facet = $self->facet_counts->{facet_fields}->{$field};
        next if(!$facet || scalar(@$facet) == 0 || (scalar(@$facet) == 2 && $facet->[1] == $hits)); #i.e. facet won't reduce resultset.
        my @results;
        for(my $i=0; $i<scalar(@$facet); $i+=2){
            push @results, { display_value => $facet->[$i], value => "\"$facet->[$i]\"", count => $facet->[$i+1] };
        }
        # artificially add wildcard on availability (it's a facet query defined in solrconfig.xml)
        # There may be a better way to do this.
        if($field eq 'availability_facet' || $field eq 'on-shelf-at'){
            unshift @results, { value => "*", count => $self->facet_counts->{facet_queries}->{"on-shelf-at:*"}, display_value => "Anywhere" };
        }
        push @facets, { field => $field, display => $display, 'values' => \@results };
    }
    #warn p @facets;
    return \@facets;
};
use WebService::Solr::Response;
my $meta = Class::MOP::Class->initialize("WebService::Solr::Response");
$meta->make_mutable;
$meta->add_method( 'koha_facets' => $koha_facets );
$meta->make_immutable;


no Moose;
1;

