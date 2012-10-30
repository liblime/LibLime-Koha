package Koha::Solr::Service;

# This is just a convenience wrapper to hide the 
# mechanism for determining which solr server to
# hit.  Also approximates C4::Search's old SimpleSearch interface,
# and monkeypatches WS::Solr::Response to include koha- specific facet method.

use Koha;
use Moose;
use Method::Signatures;
use C4::Context;
use C4::Branch;
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

before 'search' => method($query, $options) {
    my @prefs = qw(bq mm);
    for my $pref ( @prefs ) {
        my $syspref = 'OPACSolr'.uc($pref);
        if (my $val = C4::Context->preference($syspref)) {
            $options->{$pref} //= [];
            push $options->{$pref}, $_
                for split /\|/, $val;
        }
    }
    # get all branch facets so we can sort by branch display name.
    $options->{'f.on-shelf-at.facet.limit'} = -1;
};

has facet_limit => ( is => 'ro', isa => 'Int', default => 12 );

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
    my $FACET_LIMIT = $self->content->{responseHeader}->{params}->{'facet.limit'} // 12;  # FIXME: Set in solrconfig.
    my $hits = $self->content->{response}->{numFound};
    for my $facetspec (split(/\s*,\s*/,C4::Context->preference('SearchFacets'))){
        my ($field, $display) = split(':',$facetspec);
        $display = $field unless $display;
        my $facet = $self->facet_counts->{facet_fields}->{$field};
        next if(!$facet || scalar(@$facet) == 0 || (scalar(@$facet) == 2 && $facet->[1] == $hits)); #i.e. facet won't reduce resultset.
        my @results;
        for(my $i=0; $i<scalar(@$facet); $i+=2){
            my $display_value = $facet->[$i];
            given ($field){
                when ('on-shelf-at'){
                    $display_value = C4::Branch::GetBranchName($facet->[$i]);
                } when ('itemtype'){
                    $display_value = C4::Koha::getitemtypeinfo($facet->[$i])->{description};
                } when ('collection'){
                    my $ccode = C4::Koha::GetAuthorisedValue('CCODE',$facet->[$i]);
                    $display_value = $ccode->{opaclib} || $ccode->{lib};
                }
            }
            push @results, { display_value => $display_value, value => "\"$facet->[$i]\"", count => $facet->[$i+1] } if($facet->[$i]);
        }

        if($field ~~ 'on-shelf-at'){
            my @sorted_branchfacet = sort { lc($a->{display_value}) cmp lc($b->{display_value}) } @results;
            # artificially add wildcard on availability (it's a facet query defined in solrconfig.xml)
            # There may be a better way to do this.
            unshift @sorted_branchfacet, { field => "url", value => "*", count => $self->facet_counts->{facet_queries}->{"url:*"}, display_value => "Online" };
            unshift @sorted_branchfacet, { value => "*", count => $self->facet_counts->{facet_queries}->{"on-shelf-at:*"}, display_value => "Anywhere" };
            # FIXME: now we add offset to sorted facet.  This needs to be generalised so that
            # any facet with a display value != facet value can be resorted A-Z.  Currently
            # we only sort branch facet A-Z, and do not allow resorting.
            my $start_slice = $self->content->{responseHeader}->{params}->{'facet.offset'} // 0;
            my $end_slice = $start_slice + (scalar(@results) < $FACET_LIMIT - 2) ? scalar(@results) + 1 : $FACET_LIMIT - 1;
            @results = @sorted_branchfacet[$start_slice .. $end_slice];
        }
        push @facets, { field => $field, display => $display, 'values' => \@results, 'expandable' => (scalar(@results) >= $FACET_LIMIT) ? 1 : 0 };
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

