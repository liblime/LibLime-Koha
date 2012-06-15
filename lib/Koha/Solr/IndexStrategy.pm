package Koha::Solr::IndexStrategy;

use Koha;
use Moose::Role;
use namespace::autoclean;
use Method::Signatures;

has 'rules_text' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    );

has 'indices' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => \&_build_parser,
    lazy => 1,
    );

has 'filter_base' => (
    is => 'ro',
    isa => 'Str',
    default => 'Koha::Solr::Filter',
    );

requires '_build_source_handlers';

method _build_filter_handlers(Str @filters) {
    my @handlers;

    my %packages;
    for my $filter (@filters) {
        my $path = ($filter =~ /^\+(.*)/)
            ? $1
            : $self->filter_base . '::' . $filter;
        my ($package) = ($path =~ /(.*)::.*$/);
        $packages{$package} = 1 if $package;
        push @handlers, \&$path;
    }

    my $requires = join '', (map {"require $_;"} keys %packages);
    eval "$requires";

    return \@handlers;
}

method _build_parser {
    my @raw_rules =
        grep { $_->[0] && $_->[1] }
        map  { [ map { s/^\s+|\s+$//g; $_ } split /\|/] }
        grep { $_ !~ /^#/ }
        split /\n/, $self->rules_text;

    my @parsed_rules;
    for (@raw_rules) {
        my @sources = split /\s+/, $_->[1];
        my $source_handlers = $self->_build_source_handlers(@sources);

        my @filters = split /\s+/, ($_->[2] // '');
        my $filter_handlers = $self->_build_filter_handlers(@filters);

        my @reducers = split /\s+/, ($_->[3] // '');
        my $reducer_handlers = $self->_build_filter_handlers(@reducers);

        push @parsed_rules,
            [$_->[0], $source_handlers, $filter_handlers, $reducer_handlers];
    }

    return \@parsed_rules;
}

method index_to_array($item) {
    my @index_fields;

    for my $rule (@{$self->indices}) {
        my @unreduced;
        for (@{$rule->[1]}) {
            # render values from source rules
            my @inputset = map {$_->($item)} @{$_};
            # skip undefined values
            next unless @inputset;
            # push values through filter chain
            @inputset = $_->(@inputset) for @{$rule->[2]};

            push @unreduced, grep {$_} @inputset;
        }
        @unreduced = $_->(@unreduced) for @{$rule->[3]};
        push @index_fields, map { [ $rule->[0], $_ ] } @unreduced;
    }
    return \@index_fields;
}

method index_to_xml($item) {
    my $fields = $self->index_to_array($item);
    my @xml_fields =
        map {sprintf '  <field name="%s">%s</field>', $_->[0], $_->[1]} @$fields;
    my $xml = sprintf "<doc>\n%s\n</doc>", join("\n", @xml_fields);
    return $xml;
}

no Moose::Role;
1;
