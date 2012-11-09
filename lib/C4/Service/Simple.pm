package C4::Service::Simple;

use strict;
use warnings;

use C4::Auth qw( check_api_auth );

use JSON;
use CGI;
use Data::Dumper;
use Try::Tiny;

# {{{ Documentation
#
# Copyright 2012 LibLime
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

=head1 NAME

C4::Service::Simple - Simple RESTful webservices

=head1 SYNOPSIS

C4::Service::Simple->new($config)->dispatcher();

=head1 DESCRIPTION

This module includes several functions for implementing simple RESTful
webservices exposing CRUD operations on a simple data model.  Primarily
intended for GetIt.

=head2 HTTP response

HTTP response is an appropriately serialized object.  For single record
results:
    {record => {field => val, ... } }

For searches which return multiple records, typically with a start and limit
value, the selected records and total row count are returned:
    {records => [{field => val, ... }, ...], count => N }

For errors, the error message is returned as a scalar (i.e., not a serialized
object).

=head2 Configuration object

$config (passed to new) is a hashref which configures the controller,
model, and view components.  Reasonable defaults are available for 
nearly everything.  For examples, see the GetIt 'koha_suggestions' and
'koha_borrowers' integration services.

$config = {
    controller  => $controller_config,
    model       => $model_config,
    view        => $view_config,
    debug       => $debug_flag
}

=head2 Controller config

$controller_config = {
    routes => [
        {method => $r, service => $s, subservice => $ss,
         permissions => $p, action => $m},
        ...
    ]
}

Routes are tried in the order they are specified.

Method is a request method (GET, POST, PUT, DELETE); if not specified,
any request method will match.  Service is a service name (i.e., the first
component of the request path) to match; if not specified, any service
will match.  Subservice matches the first path component after the record
ID (e.g., bar in /foo/1/bar) and is also optional

Permissions is an optional hashref permissions set to use for permissions
checks.

Action is an optional action to invoke.  If not present, a default action
will be used ($self->GET, $self->PUT, etc).  If a coderef, it is called
with a 'query' hashref:

$query = {
    CGI     => CGI object
    cookie  => CGISESSID cookie
    path    => request path
    method  => request method
    service => service
    id      => record ID (if present)
    data    => PUTDATA or POSTDATA (if present)
}

If the action is a hashref it is interpreted as an HTTP response:

$action = {
    status  => HTTP status (defaults to '200 OK')
    type    => content type (defaults to $config->{view}{type})
    content => content
}

=head2 Model config

$model_config = {
    primary_key => $keyname,

    create      => $create_func,
    retrieve    => $retrieve_func,
    search      => $search_func,
    update      => $update_func,
    delete      => $delete_func,

    search_fields => [qw(field1 field2 ...)],
    abstract_search => (1|0)
}

Primary key is mandatory.

All CRUD functions are optional, but, if a request method is routed to the
default handler, the corresponding CRUD function must be defined.  If you
specify a search function but no retrieve function, a retrieve will be made
automatically as a wrapper around search for the primary key, returning a
single record.

Create should take a hashref, and return the hashref with the primary key
Delete should take a primary key value, and return 1
Update should take a primary key and hashref, and return a hashref
Retrieve should take a primary key value, and return the hashref

Search should take a hashref of options, and return an array of hashrefs
in scalar context, or an array of hashrefs and the total count in list
context.  If abstract_search is enabled (the default), the options are:

    where: optional SQL::Abstract style 'where' object
    order: optional SQL::Abstract style 'order' object
    limit: optional scalar count or [start,count]
    columns: optional arrayref of columns to return

If abstract search is disabled, the options are:
    q:     the query text (CGI 'q' parameter)
    start: optional start record (from 0)
    limit: optional number of records to return
    sort:  optional sort column
    dir:   optional sort direction

Operation functions should return (undef, $error_string) in the event
of an error, or (undef, undef) to indicate no error but record not
found.

It is expected that the columns utilized by the CRUD operations may span
several tables with appropriate joins; it is up to the update and create
functions to handle (or ignore) foreign columns appropriate.  Note that 
the hashref passed to the create and update functions may include fields
which DO NOT correspond to actual columns.  Typically, update will check
against existing record column names, and create will check against the
schema.

The search fields is an optional set of default fields to use in abstract
searches.  seaches If the query argument (q) does not explicitly specify
the query as a serialized object, it is interpreted as a scalar, and an
OR query is conducted over all of the search fields.

=head2 View config

$view_config = {
    import_map => {to_field => $spec, ...},
    export_map => {to_field => $spec, ...},
    decode     => $decode_func,
    encode     => $encode_func,
    type       => $content_type
}

Decode and encode are the functions used to deserialize and serialize, 
respectively, the data for web transport.  They default to decode_json
and encode_json, respectively.  Type is the content type and defaults
to 'application/json'.

Import and export maps are optional translation maps which translate
the fields known internally into Koha-branch-independent forms.  The
key is the field name after translation; the value is either a scalar
field name or a code reference, which is called with the unmapped
hashref and should return a scalar field value.  If a translation map
is specified, ALL fields must be mapped, even if to themselves.

=cut
# }}}

# {{{ sub new
=head1 METHODS

=head2 new

=over 4

    my $rest_hander = new C4::Service::Simple($config);

=back

Create a new REST handler object.  Config as above.  Typically called
with an immediate call to dispatcher(), so you can chain these as

    C4::Service::Simple->new($config)->dispatcher();

=cut
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = shift || {};

    $self->{default}{GET} = \&GET;
    $self->{default}{PUT} = \&PUT;
    $self->{default}{POST} = \&POST;
    $self->{default}{DELETE} = \&DELETE;

    bless($self, $class);

    $self->{debug} //= $ENV{DEBUG} // 0;

    my $query = ($self->{query} //= {});
    $query->{CGI}    //= CGI->new();
    $query->{cookie} //= $query->{CGI}->cookie('CGISESSID');
    $query->{path}   //= $query->{CGI}->path_info;
    $query->{method} //= $query->{CGI}->request_method;

    my ($service, $id, $subservice, @extra) = split(/\//, $query->{path});
    $query->{service} //= $service;
    $query->{subservice} //= $subservice;

    if (defined($id) and ($id ne '')) {
        $query->{id} //= $id;
    }
    
    if ($query->{method} eq 'PUT') {
        $query->{data} //= $query->{CGI}->param('PUTDATA');
    }
    elsif ($query->{method} eq 'POST') {
        $query->{data} //= $query->{CGI}->param('POSTDATA');
    }

    return($self);
}
# }}}

# {{{ sub dispatcher
=head2 dispatcher

=over 4

    $rest_hander->dispatcher();

=back

Dispatch and handle HTTP requests based on config.  Returns 1 on
success, or undef if the route was not found.

=cut
sub dispatcher {
    my $self = shift;
    my $query = $self->{query};

    my $input = $query->{data} // '';
    if ($input) {

        warn "Dispatcher input = $input" if ($self->{debug});

        my $decode = $self->{view}{decode} || \&decode_json;
        my $err = undef;
        try {
            $input = &{$decode}($input);
        }
        catch {
            $err = "Deserialization of input data failed: $_";
        };

        # TODO - ExtJS (at least as used via GetIt) expects, and generates, a particular object format which includes 
        # 'out-of-band' communication in response->status and response->error.  This may need to be refactored to 
        # provide this format on output (e.g., content => {response => {error => 'foo'}}), and anticipate it on input 
        # (e.g., expecting to see $input->{response}{error} or $input->{response}{content} if !$input->{record}).  On
        # the other hand, other users may want error messages in non-JSON format, so, this should be configurable.

        return $self->http_response({status => '500 Bad Request', content => $err}) if (defined($err));
        return $self->http_response({status => '500 Bad Request', content => "Unable to retrieve record"}) unless ($input->{record});

        $query->{data} = $input->{record};
        warn "Dispatcher deserialized input = ", Dumper($input) if ($self->{debug});
    }

    my $routes = $self->{controller}{routes} || [];
    foreach my $route (@$routes) {
        warn "Check Method=" . $route->{method} . " service=" . $route->{service} . " subservice=" . $route->{subservice} if ($self->{debug});
        next if (defined($route->{method}) and ($route->{method} ne $query->{method}));
        next if (defined($route->{service}) and ($route->{service} ne $query->{service}));
        next if (defined($route->{subservice}) and ($route->{subservice} ne $query->{subservice}));

        warn "Match Method=" . $route->{method} . " service=" . $route->{service} . " subservice=" . $route->{subservice} if ($self->{debug});

        my ($ok, $err) = $self->auth_quickcheck($query->{cookie}, $route->{permissions});
        return $self->http_response({status => '403 Forbidden', content => $err || 'Authentication failed'}) if (!$ok);

        my $action = $route->{action} // $self->{default}{$query->{method}};
        if (ref($action) eq 'HASH') {
            return $self->http_response($action);
        }
        elsif (ref($action) eq 'CODE') {
            my @rv;
            try {
                @rv = &{$action}($self, $query);
            }
            catch {
                @rv = (undef, $_);
                warn "Caught error: $_";
            };
            return $self->status_of(@rv);
        }
        else {
#           return $self->http_response({status => '500 Bad Request', content => {response => {error => "Bad route action for request method " . $query->{method} }} });
            return $self->http_response({status => '500 Bad Request', content => "Bad route action for request method " . $query->{method}});
        }
    }

    # Fall through; no route found
    return undef;

}
# }}}
# {{{ sub GET
=head2 GET

=over 4
    ($record, $err) = $hdlr->GET({id => $primarykey});
    ($records, $count_or_err) = $hdlr->GET({query => $CGI});
=back

Retrieve one or more records using the configured search and/or retrieve
operations.  If an ID (primary key value) is passed, a single record is
returned as a hashref.  If no ID is passed, and a CGI object is available,
a query is constructed based upon the CGI parameters, and an arrayref of
records (as hashrefs) is returned.  A count of total rows (not limited by
the start/limit parameters) is also returned.

CGI parameters are:

=over 4
    q       Query string or serialized SQL::Abstract clause (required)
    start   Record number to start with (from 0)
    limit   Total records to return
    sort    Column name to sort on
    dir     Sort direction
=back

If abstract search is enabled (the default), and the query starts with a
bracket character, it is assumed to be a serialized object, and is
deserialized using the configured decoder (in the view config).  Otherwise,
if abstract search is enabled, a query is constructed testing if any of the
predefined search fields (in the model config) are LIKE the search string.
The query can be an empty string ''.

The column names in the sort and query are mapped using the import map, if 
present, to allow these to be Koha-branch-independent.

In the event of an error, the first argument returned will be undef, the
second will contain an error string.  If no records are found, the return
is (undef,undef).

=cut

sub GET {
    my $self = shift;
    my ($req) = @_;
    
    my $record_id = $req->{id};
    my $query     = $req->{CGI};
    
    my $get_function    = $self->{model}{retrieve};
    my $search_function = $self->{model}{search};
    my $abstract_search = $self->{model}{abstract_search} // 1;

    if ($search_function and !$get_function) {
        $get_function = $self->{model}{retrieve} = sub {
            my $id = shift;
            my ($records, $err) = &$search_function({where => {$self->{model}{primary_key} => $id}});
            return(undef, $err) if (!$records);

            return($records->[0]);
        }
    }

    if ($record_id) {
        return(undef, "Retrieve operation unimplemented") if (!$get_function);

        warn "GET request for entity $record_id" if ($self->{debug});
        my ($record,$err) = &$get_function($record_id);
        warn "GET request returned unmapped record ", Dumper($record) if ($self->{debug});

        return(undef, $err) if (!$record);

        return $self->map_fields($record, $self->{view}{export_map});
    }

    elsif ($query and defined(my $q = $query->param('q'))) {
        return(undef, "Search operation unimplemented") if (!$search_function);

        # Don't need to sanitize $q; SQL::Abstract will take care of that
        my $start = sanitize($query->param('start'));
        my $limit = sanitize($query->param('limit'));
        my $sort  = sanitize($query->param('sort'));
        my $dir   = sanitize($query->param('dir'));
        
        my $search_args;
        if ($abstract_search) {
            my ($query_where, $query_order, $query_limit);
            if ($q and ($q =~ /^[\{\<\[]/)) {
                my $decode = $self->{view}{decode} || \&decode_json;
                my $err = undef;
                try {
                    $query_where = $self->remap_query_fields(&{$decode}($q), $self->{view}{import_map});
                }
                catch {
                    $err = "Bad query syntax: $_";
                };
                return(undef,$err) if (defined($err));
            }
            elsif ($q) {
                $query_where = [];
                foreach my $field (@{$self->{model}{search_fields}}) {
                    push(@$query_where, $field, {-like => '%' . $q . '%'});
                }
            }
            
            # Intentionally treating 0 as false.
            if ($start and $limit) {
                $query_limit = [$start, $limit];
            }
            elsif ($limit) {
                $query_limit = $limit;
            }
            elsif ($start) {
                warn "C4::Service::Simple: start specified without limit; using default of 15\n";
                $query_limit = [$start,15];
            }

            if ($sort and $dir) {
                if (uc($dir) eq 'ASC') {
                    $query_order = {-asc => $self->mapped_field_name($sort, $self->{view}{import_map})};
                }
                elsif (uc($dir) eq 'DESC') {
                    $query_order = {-desc => $self->mapped_field_name($sort, $self->{view}{import_map})};
                }
                else {
                    warn "C4::Service::Simple: bad sort dir $dir specified\n";
                    $query_order = {-asc => $self->mapped_field_name($sort, $self->{view}{import_map})};
                }
            }
            elsif ($sort) {
                $query_order = {-asc => $self->mapped_field_name($sort, $self->{view}{import_map})};
            }
            
            $search_args = {where => $query_where, order => $query_order, limit => $query_limit, count => 1};
        }
        else {
            # Not doing abstract search; just pass query through to function as raw text
            $search_args = {query => $q, start => $start, limit => $limit, sort => $sort, dir => $dir};
        }

        warn "GET request for multiple entities: ", Dumper($search_args) if ($self->{debug});

        my ($records, $total_count) = &$search_function($search_args);
        warn "GET request returned unmapped records ", Dumper($records) if ($self->{debug});

        return(undef, $total_count) if (!$records);

        map { $_ = $self->map_fields($_, $self->{view}{export_map}) } @$records;
        return ($records, $total_count);
    }
    else {
        return(undef, "Bad query condition");
    }
}
# }}}
# {{{ sub PUT
=head2 PUT

=over 4

    ($record,$err) = $hdlr->PUT({id => $key, data => $record});
=back

Handle PUT requests by passing off to the update operation.
Returns updated record on success, (undef, undef) if the record was not found,
not found, or (undef, $error) in the event of an error.

=cut
sub PUT {
    my $self = shift;
    my ($req) = @_;
    
    my $record_id = $req->{id};
    my $record = $req->{data};
    
    warn "PUT request unmapped input: ", Dumper($record) if ($self->{debug});
    my $put_function = $self->{model}{update}; 
    return(undef, "Update operation unimplemented") if (!$put_function);

    $record = $self->map_fields($record, $self->{view}{import_map});
    warn "PUT request record $record_id mapped input: ", Dumper($record) if ($self->{debug});

    my ($updated_record,$err) = &$put_function($record_id, $record);
    return(undef, $err) if (!$updated_record);

    return $self->map_fields($updated_record, $self->{view}{export_map});
}
# }}}
# {{{ sub POST
=head2 POST

=over 4

    ($record,$err) = $hdlr->POST({data => $record});
=back

Handle POST requests by passing off to the create operation.

Returns record with key on success, or (undef, $error) if the record could 
not be created.

=cut
sub POST {
    my $self = shift;
    my ($req) = @_;

    my $record = $req->{data};
    my $post_function = $self->{model}{create};
    return(undef, "Create operation unimplemented") if (!$post_function);

    $record = $self->map_fields($record, $self->{view}{import_map});
    my ($updated_record, $err) = &$post_function($record);
    return(undef, $err) if (!$updated_record);
   
    return $self->map_fields($updated_record, $self->{view}{export_map});
}
# }}}
# {{{ sub DELETE
=head2 DELETE

=over 4

    ($ok,$err) = $hdlr->DELETE({id => $key});
=back

Handle DELETE requests by passing off to the delete operation.

Returns 1 for success, (undef, undef) if the record was not found, or 
(undef, $error) for error.

=cut
sub DELETE {
    my $self = shift;
    my ($req) = @_;

    my $record_id = $req->{id};
    my $delete_function = $self->{model}{'delete'};
    return(undef, "Delete operation unimplemented") if (!$delete_function);

    my $primary_key = $self->{model}{primary_key};
    my ($ok, $err) = &$delete_function($record_id);
    return (undef, $err) if (!$ok);

    return $self->map_fields({$primary_key => $record_id}, $self->{view}{export_map});
}
# }}}

# {{{ sub auth_quickcheck
=head2 auth_quickcheck

=over 4

    ($ok,$err) = $hdlr->auth_quickcheck($cookie, $permissions);
=back

Authenticate $cookie against the permissions set $permissions using the 
C4::Auth::check_cookie_auth function.  Returns 1 for OK, (undef, $error)
for failure.

=cut
sub auth_quickcheck {
    my $self = shift;
    my ($cookie, $permissions) = @_;

    return 1 if (!defined($permissions));
    
    warn "auth_quickcheck:FIRST:cookie=$cookie, permissions=$permissions\n" if ($self->{debug});

    my ($status, undef) = C4::Auth::check_cookie_auth($cookie, $permissions);
    warn "auth_quickcheck:back from check_cookie_auth. status=$status.\n" if ($self->{debug});
    
    return(undef, $status) if (!($status ~~ 'ok'));

    return(1);
}
# }}}

# {{{ sub status_of
=head2 status_of

=over 4
    $hdlr->status_of($objects, $count_or_error);
=back

Issue an HTTP response appropriate for the return values of any of the
built-in CRUD operations.  This is intended to be chained with the CRUD
operation function, e.g., $hdlr->status_of($hdlr->GET(...))

If $objects is a hashref, a 200 OK with a serialized single record is issued.

If $objects is an arrayref, a 200 OK with serialized multiple records, and a
count, is returned.

If $objects is undefined but $count_or_error is defined, a 500 Bad Request
with the error string is issued.

If neither $objects nor $count_or_error is defined, a 404 Not Found is issued.

=cut
sub     status_of {
    my $self = shift;
    my ($objs, $count) = @_;

    warn "Status_of: ", Dumper([$objs,$count]) if ($self->{debug});

    if (!defined($objs) and defined($count) and ($count ne '0')) {
#       return $self->http_response({status => '500 Bad Request', content => {response => {error => $count || 'Bad request'}} });
        return $self->http_response({status => '500 Bad Request', content => $count || 'Bad request'});
    }
    elsif (!defined($objs)) {
        return $self->http_response({status => '404 Not Found'});
    }
    elsif (ref($objs) eq 'HASH') {
        return $self->http_response({content => {record => $objs}});
    }
    elsif (ref($objs) eq 'ARRAY') {
        return $self->http_response({content => {records => $objs, count => $count}});
    }
    else {
#       return $self->http_response({status => '500 Bad Request', content => {response => {error => "Unexpected condition in status_of"}} });
        return $self->http_response({status => '500 Bad Request', content => "Unexpected condition in status_of"});
    }
}
# }}}
# {{{ sub http_response
=head2 http_response

=over 4
    $hdlr->http_response($response);
=back

Issue an HTTP response based upon hashref $response.  Fields in the hashref
include:

    type        Content-type; defaults to type in view config, or to JSON
    status      HTTP status code; defaults to '200 OK'
    content     Content to return

If the content is a reference (hashref or arrayref), it is serialized using 
the configured serializer function (defaulting to JSON encoding).

=cut
sub     http_response {
    my $self = shift;
    my ($resp) = @_;

    my $content = $resp->{content} // '';
    if (ref($content)) {
        my $encode = $self->{view}{encode} || \&encode_json;
        $content = &{$encode}($content);
    }

    my $options = {
        type    => $resp->{type} // $self->{view}{type} // 'application/json',
        status  => $resp->{status} // '200 OK',
        charset => 'UTF-8',
        Pragma  => 'no-cache',
        'Cache-Control' => 'no-cache',
        cookie  => $self->{query}{cookie}
    };

    binmode STDOUT, ":utf8";
    print $self->{query}{CGI}->header($options), $content;

    return 1;
}
# }}}

# {{{ sub map_fields
=head2 map_fields (internal function)

    $hashref = $handler->map_fields($hashref, $map)

Convert fields using the specified map $map.  Intended for translation between
Koha-version-dependent and Koha-version-independent field names.  $map is a
hashref of {to_field => from_spec}, where to_field is the field name, and
from_spec is either a scalar (from field name), or coderef (called with the
input hashref as the only arg).  The coderef function can return an empty list
to indicate that the field should not be mapped.

=cut
sub map_fields {
    my $self = shift;
    my ($input, $map) = @_;

    return($input) if (!defined($map));

    my $output = {};
    foreach my $to_field (keys %$map) {
        my $from_spec = $map->{$to_field};

        if (!defined($from_spec)) {
            ;
        }
        elsif (!ref($from_spec)) {
            $output->{$to_field} = $input->{$from_spec} if (exists($input->{$from_spec}));
        }
        elsif (ref($from_spec) eq 'CODE') {
            my @rv = &{$from_spec}($input);
            $output->{$to_field} = $rv[0] if (scalar(@rv));
        }
    }

    return($output);
}
# }}}
# {{{ sub mapped_field_name
=head2 mapped_field_name (internal function)

    $field = $handler->mapped_field_name($field, $map)

Convert a single field from unmapped to mapped name using the translation 
map.  This is only feasible for simple {foo => bar} map entries, obviously,
and won't work for coderef mappings.
=cut

sub mapped_field_name {
    my $self = shift;
    my ($field, $map) = @_;

    return($field ) if (!defined($map));

    foreach my $to_field (keys %$map) {
        my $from_spec = $map->{$to_field};
        if (!ref($from_spec) and ($from_spec eq $field)) {
            return($to_field);
        }
    }

    return($field);
}
# }}}
# {{{ sub remap_query_fields
=head2 remap_query_fields (internal function)

    $query = $handler->remap_query_fields($query, $map)

Translate the field names an SQL::Abstract style query using the specified
map.  This is used to let outside world to use Koha-branch-independent
names when conducting queries.

=cut
sub remap_query_fields {
    my $self = shift;
    my ($query, $map) = @_;

    return($query) if (!defined($map));
    
    if (ref($query) eq 'ARRAY') {
        foreach my $ent (@$query) {
            if (ref($ent)) {
                $ent = $self->remap_query_fields($ent, $map);
            }
            elsif ($ent =~ /^\w/) {
                $ent = $self->mapped_field_name($ent, $map);
            }
        }
        return($query);
    }
    elsif (ref($query) eq 'HASH') {
        my $new = {};
        while (my ($ent, $v) = each %$query) {
            if (ref($ent)) {
                $ent = $self->remap_query_fields($ent, $map);
            }
            elsif ($ent =~ /^\w/) {
                $ent = $self->mapped_field_name($ent, $map);
            }

            $v = $self->remap_query_fields($v, $map);

            $new->{$ent} = $v;
        }
        return($new);
    }
    else {
        return($query);
    }
}
# }}}
# {{{ sanitize
=head2 sanitize

=over 4

    $safe = sanitize($unsafe)

=back

Very simple sanitization on text to be passed to SQL for use in sort and limit
clauses.  Rejects anything that's not alphanumeric, underscore, or dot.

=cut

sub sanitize {
    my ($val) = @_;

    $val //= '';
    if ($val =~ /^[\d\w_\.]*$/) {
        return($val);
    }
    else {
        warn "C4::Service::REST: ignoring potentially unsafe query clause field '$val'\n";
        return('');
    }
}
# }}}

1;

__END__

=head1 AUTHORS

Koha Development Team

William White <frogomatic@gmail.com>
