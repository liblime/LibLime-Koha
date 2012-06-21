package Koha::Solr::Service;

# This is just a convenience wrapper to hide the 
# mechanism for determining which solr server to
# hit.  It doesn't do anything interesting now
# beyond saving 33 keystrokes.

use Moose;
use C4::Context;

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

# Class method
# Would be nice to subclass WS::Solr::Response and add facet handling
# there.
# Hack facet handling into WS::Solr::Response...

use DDP;

my $koha_facets = sub {
    my $self = shift;
    return unless C4::Context->preference('OpacFacets');
    my $facet_spec = C4::Context->preference('OpacFacets');
    my @facets;
    my $hits = $self->content->{response}->{numFound};
    for my $facetspec (split(/\s*,\s*/,C4::Context->preference('OpacFacets'))){
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

